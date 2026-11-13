import QtQuick
import "mail-store.js" as Store

QtObject {
    id: state
    property color agentInk
    property var reduceAction: Store.reduce
    property var data: Store.emptyMailbox()
    onMailboxClientChanged: if (mailboxClient) mailboxClient.loadAccounts()
    readonly property var ui: data.ui
    readonly property var selectedRow: Store.current(data)
    property MailThreadQuery threadQuery: MailThreadQuery {
        client: state.mailboxClient
        account: state.selectedRow?.backendAccount ?? ""
        conversation: state.selectedRow?.backendConversation ?? ""
    }
    readonly property var threadMessages: Store.fromMailbox(data, threadQuery.messages).messages

    readonly property var selected: {
        if (!selectedRow || !threadMessages.length)
            return selectedRow;
        const current = threadMessages.find(message => message.id === selectedRow.id);
        if (!current)
            return selectedRow;
        return Object.assign({}, selectedRow, {
            bodyHtml: current.bodyHtml,
            files: current.files,
            history: threadMessages.filter(message => message.id !== current.id).map(message =>
                Object.assign({}, message, {date: [message.day, message.time].join(" "), expanded: false}))
        });
    }
    readonly property bool canReplyAll: Store.canReplyAll(selected, accounts)
    readonly property var draft: Store.draft(data)
    property var mailboxClient: null
    property var outbox: ({})
    property Connections outboxResponses: Connections {
        target: state.mailboxClient
        ignoreUnknownSignals: true
        function onAccountsLoaded(accounts, ok) {
            if (!ok)
                return;
            state.data = Object.assign({}, state.data, {
                accounts: accounts.map(account => ({
                    id: account.id,
                    name: account.id === "work" ? "Work" : account.id === "personal" ? "Personal" : account.name,
                    email: account.email,
                    provider: account.provider
                }))
            });
        }
        function onMessageUpdated(id, ok) {
            if (ok) {
                if (state.folderQuery.key)
                    state.folderQuery.refresh();
                state.threadQuery.refresh();
            } else {
                state.act("notice", {text: qsTr("Could not update the message.")});
            }
        }
        function onMailboxInvalidated() {
            if (state.folderQuery.key)
                state.folderQuery.refresh();
            state.threadQuery.refresh();
            state.draftQuery.refresh();
        }
        function onOutboxChanged(job) {
            const active = state.draft;
            if (active && (state.savedDraftIds[active.id] || active.backendId) === job.message_id
                    && ["queued", "sending", "sent"].includes(job.state)) {
                state.data = Object.assign({}, state.data, {
                    drafts: state.data.drafts.filter(draft => draft.id !== active.id),
                    ui: Object.assign({}, state.ui, {view: "read", draftId: ""})
                });
            }
            const next = Object.assign({}, state.outbox);
            if (job.state === "sent") {
                delete next[job.id];
                state.draftQuery.refresh();
            }
            else
                next[job.id] = job;
            state.outbox = next;
            if (job.state === "failed" || job.state === "uncertain")
                state.act("notice", {text: job.last_error || qsTr("Message delivery failed.")});
        }
    }
    property MailDraftQuery draftQuery: MailDraftQuery {
        client: state.mailboxClient
        onRefreshed: messages => {
            const loaded = Store.fromMailbox(state.data, messages, state.data.messages).drafts;
            const working = state.data.drafts.filter(draft =>
                !draft.backendId || draft.id === state.ui.draftId && ["draft", "compose"].includes(state.ui.view));
            const represented = new Set(working.map(draft => state.savedDraftIds[draft.id] || draft.backendId));
            state.data = Object.assign({}, state.data, {
                drafts: working.concat(loaded.filter(draft => !represented.has(draft.id)))
            });
        }
        onErrorChanged: if (error) state.act("notice", {text: error})
    }
    property MailDraftSync draftSync: MailDraftSync {
        client: state.mailboxClient
        onFailed: message => state.act("notice", {text: message})
    }
    readonly property var savedDraftIds: draftSync.savedDraftIds
    readonly property bool draftSaving: draftSync.saving
    property MailSearchQuery searchQuery: MailSearchQuery {
        client: state.mailboxClient
        active: state.ui.searching
        term: state.ui.query
        onCompleted: (messages, ok) => {
            if (!ok) {
                state.act("notice", {text: qsTr("Could not search the local mailbox.")});
                return;
            }
            const updated = Object.assign({}, state.data);
            const hits = Store.fromMailbox(updated, messages).messages;
            const known = new Set(updated.messages.map(message => message.id));
            updated.messages = updated.messages.concat(hits.filter(message => !known.has(message.id)));
            updated.searchIds = hits.map(message => message.id);
            state.data = updated;
        }
    }
    property MailboxQuery folderQuery: MailboxQuery {
        client: state.mailboxClient
        account: state.ui.account === "Work" ? "work" : state.ui.account === "Personal" ? "personal" : ""
        folder: ["Inbox", "Archive", "Trash", "Junk", "Sent"].includes(state.ui.folder)
            && !state.ui.searching ? state.ui.folder : ""
        onRefreshed: messages => {
            if (!folder)
                return;
            const updated = Object.assign({}, state.data);
            const fresh = Store.fromMailbox(updated, messages).messages;
            updated.messages = updated.messages.filter(row => row.folder !== folder
                || account && row.backendAccount !== account).concat(fresh);
            if (!updated.ui.selected && fresh.length && updated.ui.view === "read")
                updated.ui = Object.assign({}, updated.ui, {selected: fresh[0].id});
            updated.drafts = updated.drafts.map(draft => {
                if (draft.conversation || !draft.backendConversation)
                    return draft;
                const source = updated.messages.find(row => row.backendConversation === draft.backendConversation
                    && row.account === draft.account && row.folder !== "Sent");
                return source ? Object.assign({}, draft, {conversation: source.id, mode: "Reply"}) : draft;
            });
            state.data = updated;
        }
    }
    property var rows: []
    onDataChanged: {var next=Store.results(data);if(JSON.stringify(next)!==JSON.stringify(rows))rows=next;}
    readonly property var settings: data.settings
    readonly property var accounts: data.accounts
    readonly property bool canSend: !draftSync.sendingId && Store.canSend(draft)
    readonly property bool hasPending: mailboxClient ? Object.keys(outbox).length > 0 : data.jobs.length > 0
    readonly property bool undoAvailable: !mailboxClient && hasPending && (data.now <= data.jobs[data.jobs.length-1].expires || !ui.online)
    // These are requests to the future system integration, not app-owned surfaces.
    signal authorizationRequested(string provider)
    signal notificationRequested(var message)
    signal sendStatusChanged(var status)
    function completeAuthorization(email){act("providerEmail",{text:email});act("connect");}
    function notificationAction(action){
        if(action==="markRead")act("readNotification");
        else if(action==="dismiss")act("dismissNotification");
        else act("openNotification",{reply:action==="reply",agent:action==="agentReply"});
    }
    signal editorRequested()
    signal saveRequested(var file)
    property Connections attachmentResponses: Connections {
        target: state.mailboxClient
        ignoreUnknownSignals: true
        function onAttachmentFetched(messageId, attachmentId, localUrl) {
            const file = state.ui.attachment;
            if (file?.messageId !== messageId || file.id !== attachmentId)
                return;
            if (String(localUrl))
                state.act("preview", {file: Object.assign({}, file, {url: String(localUrl)})});
            else
                state.act("notice", {text: qsTr("Could not load the attachment.")});
        }
        function onAttachmentSaved(messageId, attachmentId, ok) {
            state.act("notice", {text: ok ? qsTr("Attachment saved.") : qsTr("Could not save the attachment.")});
        }
    }
    function saveAttachment(file){saveRequested(file);}
    function act(action, payload) {
        var p=payload || {};
        if(action==="draft") {var d=Store.draft(data);if(d&&Object.keys(p).every(function(k){return d[k]===p[k];}))return;}
        if(action==="setting"&&data.settings[p.key]===p.value)return;
        if (mailboxClient && action === "retry") {
            for (const job of Object.values(outbox)) {
                if (job.state === "failed" || job.state === "uncertain")
                    mailboxClient.retrySend(job.id);
            }
            return;
        }
        if (mailboxClient && action === "send") {
            if (!draft || draftSync.sendingId)
                return;
            const latest = Object.assign({}, draft, p);
            if (!Store.canSend(latest))
                return;
            draftSync.send(latest, latest.backendConversation || Store.find(data, latest.conversation)?.backendConversation || "");
            return;
        }
        if (mailboxClient && action === "discard" && draft)
            draftSync.discard(draft);
        if (mailboxClient && selected) {
            const current = selected;
            if (action === "archive")
                mailboxClient.updateMessage(current.id, {mailbox: "Archive"});
            else if (action === "move")
                mailboxClient.updateMessage(current.id, {mailbox: p.folder});
            else if (action === "unread")
                mailboxClient.updateMessage(current.id, {unread: !current.unread});
            else if (action === "star")
                mailboxClient.updateMessage(current.id, {flagged: !current.starred});
            else if (action === "select") {
                const row = Store.find(data, p.id);
                if (row?.unread)
                    mailboxClient.updateMessage(row.id, {unread: false});
            }
        }
        if (mailboxClient && action === "preview" && p.file?.messageId && !p.file.url)
            mailboxClient.fetchAttachment(p.file.messageId, p.file.id, p.file.name);
        const previousJobs=JSON.stringify(data.jobs);
        p.now=Date.now();var next=reduceAction(data,action,p);
        const jobsChanged=JSON.stringify(next.jobs)!==previousJobs;
        // Sending/Undo is reported to the system, not duplicated as an app toast.
        if(jobsChanged&&["send","tick","undoSend","retry"].includes(action))next.ui.notice="";
        if (mailboxClient && (next.ui.searching !== ui.searching || next.ui.query !== ui.query))
            next.searchIds = [];
        data=next;
        if (mailboxClient && ["new", "reply", "mode", "draft", "attach", "detach", "keepDraft"].includes(action)) {
            const changed = Store.draft(next);
            if (changed)
                draftSync.enqueue(changed, changed.backendConversation || Store.find(next, changed.conversation)?.backendConversation || "",
                    ["attach", "detach", "keepDraft"].includes(action));
        }
        if(action==="provider")authorizationRequested(ui.provider);
        if(action==="notify"&&ui.notification)notificationRequested(Store.find(data,"anna-notification"));
        if(jobsChanged)sendStatusChanged({pending:Store.copy(data.jobs),undoAvailable:undoAvailable});
    }
    function count(folder,account) { return Store.folderCount(data,folder,account); }
    function resultSnippet(message) {
        const body = message.body.replace(/\s+/g, " ");
        const query = ui.searching ? ui.query.trim().toLowerCase() : "";
        if (!query)
            return body;
        const match = body.toLowerCase().indexOf(query);
        if (match >= 0)
            return (match ? "… " : "") + body.slice(match);
        return message.files.find(file => file.name.toLowerCase().includes(query))?.name
            ?? (message.address?.toLowerCase().includes(query) ? message.address : body);
    }
    function highlight(text, ink, background){return Store.highlight(String(text),ui.searching?ui.query:"",ink,background);}
    function names(addresses){return String(addresses).split(",").map(function(a){return a.trim().split("@")[0].split(/[._]/).map(function(s){return s?s[0].toUpperCase()+s.slice(1):s;}).join(" ");}).join(", ");}
    function addressesValid(value){return Store.validRecipients(value);}
    function agentDraft(id) { return Store.agentDraft(data,id); }
    function reply(mode, agent, sourceId) {
        act("reply", {mode: mode, agent: !!agent, sourceId: sourceId});
        editorRequested();
    }
    property Timer clock: Timer { interval: 500; repeat: true; running: (!state.mailboxClient && state.hasPending) || state.ui.view === "importing" || state.data.messages.some(m=>!!m.returnAt); onTriggered: state.act("tick") }
    Component.onCompleted: {
        var next=Store.copy(data);next.now=Date.now();next.jobs.forEach(function(j){j.expires=next.now+next.settings.undoSeconds*1000;});data=next;rows=Store.results(data);
    }
}
