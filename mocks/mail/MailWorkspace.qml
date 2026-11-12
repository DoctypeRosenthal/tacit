import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Tacit.Kit as K

FocusScope {
    id: workspace
    required property var controller
    property bool prewarmHtml: false
    readonly property var t: K.Kit.tokens
    readonly property real listMinimum: t.width.rail + t.space.xl
    readonly property real readerMinimum: t.width.panel + t.space.page * 2
    readonly property bool compact: width < listMinimum + readerMinimum
    readonly property bool railFits: width >= listMinimum + readerMinimum + t.width.rail
    readonly property real railWidth: controller.ui.rail && railFits ? t.width.rail - t.space.xl - t.space.l : 0
    readonly property real listWidth: t.width.panel + t.space.page + t.space.m
    readonly property bool fullPage: ["setup", "settings"].includes(controller.ui.view)
    property bool compactReading: true
    property string selection: controller.ui.selected
    property string activeView: controller.ui.view
    onSelectionChanged: if (selection)
        compactReading = true
    onActiveViewChanged: if (["draft", "compose", "importing"].includes(activeView))
        compactReading = true

    function openMessage(id) {
        compactReading = true;
        controller.act("select", {
            id: id
        });
    }

    function showMailboxes() {
        if (compact || !railFits)
            folderPicker.openAt(folderTitle, 0, folderTitle.height);
        else
            controller.act("rail");
    }

    focus: true

    Timer {
        interval: 250
        running: workspace.prewarmHtml && workspace.visible && !htmlWarmup.attempted
            && workspace.activeView === "read" && workspace.controller.ui.folder === "Inbox"
            && workspace.controller.rows.some(row => row.bodyHtml || row.body_html || row.bodyHtmlFixture)
        onTriggered: {
            htmlWarmup.attempted = true;
            const message = workspace.controller.selected;
            if (!message?.bodyHtml && !message?.body_html && !message?.bodyHtmlFixture)
                htmlWarmup.active = true;
        }
    }

    Loader {
        id: htmlWarmup
        property bool attempted: false
        readonly property bool loaded: !!item?.ready
        active: false
        visible: false
        width: 1

        // Warm the engine with an empty document, then release the view and its profile.
        Component.onCompleted: setSource(Qt.resolvedUrl("MailHtmlView.qml"), {html: ""})
        onLoadedChanged: if (loaded) Qt.callLater(() => { htmlWarmup.active = false; })
        onStatusChanged: if (status === Loader.Error) active = false

        Timer {
            interval: 5000
            running: htmlWarmup.active
            onTriggered: htmlWarmup.active = false
        }
    }

    component Rule: Rectangle {
        height: 1
        color: K.Kit.tokens.hairline
    }
    FileDialog {
        id: files
        title: "Attach files to this local draft"
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            for (var url of selectedFiles) {
                var path = String(url);
                workspace.controller.act("attach", {
                    url: path,
                    name: decodeURIComponent(path.split("/").pop())
                });
            }
        }
    }
    FileDialog {
        id: saveFile
        property var attachment
        property var pending: []
        function openNext() {
            if (!pending.length)
                return;
            attachment = pending[0];
            pending = pending.slice(1);
            selectedFile = String(currentFolder) + "/" + encodeURIComponent(attachment.name);
            open();
        }
        onRejected: pending = []
        title: "Save attachment"
        fileMode: FileDialog.SaveFile
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: {
            const source = attachment.url || Qt.resolvedUrl(attachment.path || "");
            if (typeof previewFiles !== "undefined" && previewFiles.copy(source, selectedFile))
                workspace.controller.act("notice", {
                    text: "Saved " + attachment.name
                });
            else
                workspace.controller.act("notice", {
                    text: typeof previewFiles !== "undefined" ? previewFiles.error : "Open the attachment in its default app to save a copy."
                });
            Qt.callLater(openNext);
        }
    }
    Connections {
        target: workspace.controller

        function onSaveRequested(file) {
            const files = Array.isArray(file) ? file : [file];
            saveFile.pending = files.filter(item => item.url || item.path);
            if (saveFile.pending.length)
                saveFile.openNext();
            else
                workspace.controller.act("notice", {text: "This sample has no file bytes to save."});
        }
    }
    Shortcut {
        sequences: [StandardKey.New]
        onActivated: workspace.controller.act("new")
    }
    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: {
            workspace.compactReading = false;
            search.forceActiveFocus();
        }
    }
    Shortcut {
        sequence: "Ctrl+Return"
        enabled: workspace.controller.canSend
        onActivated: workspace.controller.act("send")
    }
    Shortcut {
        sequence: "Meta+Return"
        enabled: workspace.controller.canSend
        onActivated: workspace.controller.act("send")
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        enabled: !["draft", "compose"].includes(workspace.controller.ui.view) && (workspace.controller.undoAvailable || !!workspace.controller.ui.undo)
        onActivated: workspace.controller.undoAvailable ? workspace.controller.act("undoSend") : workspace.controller.act("undo")
    }
    Shortcut {
        sequence: "Ctrl+,"
        onActivated: workspace.controller.act("settings")
    }
    Shortcut {
        sequence: "Meta+,"
        onActivated: workspace.controller.act("settings")
    }
    Keys.onEscapePressed: workspace.controller.act("escape")

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: !workspace.fullPage

        Rectangle {
            visible: workspace.railWidth > 0
            Layout.preferredWidth: workspace.railWidth
            Layout.fillHeight: true
            color: workspace.t.windowGround

            MailMailboxRail {
                anchors.fill: parent
                controller: workspace.controller
            }
        }
        Item {
            id: inbox
            objectName: "inboxPane"
            visible: !workspace.compact || !workspace.compactReading
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: workspace.compact ? 0 : workspace.listMinimum
            Layout.preferredWidth: workspace.listWidth
            Layout.maximumWidth: workspace.compact ? Infinity : workspace.listWidth
            Rectangle {
                anchors.fill: parent
                color: workspace.t.windowGround
            }
            Rule {
                x: parent.width - 1
                width: 1
                height: parent.height
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: workspace.t.space.m
                spacing: 0
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: workspace.t.space.xxl
                    Layout.rightMargin: workspace.t.space.xxl
                    spacing: workspace.t.space.xs
                    RowLayout {
                        id: inboxHeaderRow
                        Layout.fillWidth: true
                        spacing: workspace.t.space.xxl
                        Item {
                            id: folderTitle
                            Layout.preferredWidth: folderTitleContent.implicitWidth
                            Layout.preferredHeight: workspace.t.height.field
                            MailAction {
                                objectName: "folderMenu"
                                anchors.fill: parent
                                text: ""
                                Accessible.name: workspace.controller.ui.folder + " mailboxes"
                                onActivated: workspace.showMailboxes()
                            }
                            RowLayout {
                                id: folderTitleContent
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: workspace.t.space.xs
                                K.TacitText {
                                    text: workspace.controller.ui.searching ? "Search" : workspace.controller.ui.folder
                                    size: "section"
                                    weight: "strong"
                                    cut: "display"
                                }
                                K.Symbol {
                                    visible: !workspace.controller.ui.searching
                                    text: workspace.controller.ui.rail ? "expand_less" : "expand_more"
                                    size: workspace.t.icon.row
                                    color: workspace.t.inkSec
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        MailAction {
                            objectName: "newMessage"
                            text: workspace.controller.ui.searching ? "Close search" : "New message"
                            onActivated: {
                                workspace.compactReading = true;
                                workspace.controller.ui.searching ? workspace.controller.act("closeSearch") : workspace.controller.act("new");
                            }
                        }
                    }
                    K.TacitText {
                        objectName: "mailboxCaption"
                        Layout.fillWidth: true
                        // Keep the caption close while leaving room for the folder menu's focus ring.
                        Layout.topMargin: folderTitle.y + folderTitle.height - inboxHeaderRow.height
                            + Math.max(0, workspace.t.state.focusGap + workspace.t.state.focusRing - workspace.t.space.xs)
                        size: "meta"
                        ink: "quiet"
                        wrapMode: Text.Wrap
                        text: workspace.controller.ui.searching ? workspace.controller.rows.length + " results in every account and mailbox" : workspace.controller.ui.account + (workspace.controller.ui.folder === "Inbox" ? "  ·  " + workspace.controller.count("Inbox", workspace.controller.ui.account) + " unread" : "")
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: workspace.t.space.m
                    Layout.leftMargin: workspace.t.space.xxl
                    Layout.rightMargin: workspace.t.space.xxl
                    spacing: workspace.t.space.xs

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= workspace.t.height.header * 2 + sortMenu.implicitWidth + columnSpacing ? 2 : 1
                        columnSpacing: workspace.t.space.xxl
                        rowSpacing: workspace.t.space.s
                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitWidth: workspace.t.height.header * 2
                            implicitHeight: workspace.t.height.field
                            MailSearch {
                                id: search
                                objectName: "mailSearch"
                                anchors.fill: parent
                                text: workspace.controller.ui.query
                                onTextChanged: if (text !== workspace.controller.ui.query)
                                    workspace.controller.act("search", {
                                        text: text
                                    })
                                onAccepted: workspace.controller.act("search", {
                                    text: text
                                })
                                onDismissed: workspace.controller.act("closeSearch")
                                onDown: mailList.forceActiveFocus()
                            }
                        }
                        Item {
                            id: sortMenu
                            visible: !workspace.controller.ui.searching && workspace.controller.ui.folder !== "Later"
                            implicitWidth: sortWords.implicitWidth + workspace.t.icon.rail + workspace.t.space.xs
                            implicitHeight: workspace.t.height.field
                            Layout.alignment: Qt.AlignRight
                            MailAction {
                                objectName: "viewOptions"
                                anchors.fill: parent
                                text: ""
                                Accessible.name: "Filter and sort mail"
                                onActivated: viewMenu.openAt(this, width - viewMenu.implicitWidth, height)
                            }
                            RowLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: workspace.t.space.xs
                                K.TacitText {
                                    id: sortWords
                                    text: workspace.controller.ui.filter + ", " + workspace.controller.ui.sort.toLowerCase()
                                    size: "meta"
                                    weight: "medium"
                                    ink: "quiet"
                                }
                                K.Symbol {
                                    text: "expand_more"
                                    size: workspace.t.icon.rail - workspace.t.space.xs / 2
                                    color: workspace.t.quiet
                                }
                            }
                            K.Menu {
                                id: viewMenu

                                items: [
                                    {
                                        label: "All",
                                        checked: workspace.controller.ui.filter === "All"
                                    },
                                    {
                                        label: "Unread",
                                        checked: workspace.controller.ui.filter === "Unread"
                                    },
                                    {
                                        label: "With attachments",
                                        checked: workspace.controller.ui.filter === "With attachments"
                                    },
                                    {
                                        label: "Starred",
                                        checked: workspace.controller.ui.filter === "Starred"
                                    },
                                    {
                                        rule: true
                                    },
                                    {
                                        label: "Newest first",
                                        checked: workspace.controller.ui.sort === "Newest first"
                                    },
                                    {
                                        label: "Oldest first",
                                        checked: workspace.controller.ui.sort === "Oldest first"
                                    },
                                    {
                                        label: "Sender",
                                        checked: workspace.controller.ui.sort === "Sender"
                                    },
                                    {
                                        label: "Unread first",
                                        checked: workspace.controller.ui.sort === "Unread first"
                                    }
                                ]
                                onPicked: i => i < 4 ? workspace.controller.act("filter", {
                                        value: items[i].label
                                    }) : workspace.controller.act("sort", {
                                        value: items[i].label
                                    })
                            }
                        }
                    }
                    Rule {
                        Layout.fillWidth: true
                        color: Qt.alpha(workspace.t.inkMain, workspace.t.wash.currentHover + 0.01)
                    }
                }
                K.RowList {
                    id: mailList
                    objectName: "messageList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    Layout.leftMargin: workspace.t.space.m
                    Layout.rightMargin: workspace.t.space.m
                    view.anchors.topMargin: 0
                    view.anchors.bottomMargin: 0
                    view.bottomMargin: ringSpace + workspace.t.space.m
                    label: "Messages in " + workspace.controller.ui.folder
                    model: workspace.controller.rows
                    onActivated: i => workspace.openMessage(workspace.controller.rows[i].id)
                    onCursorChanged: {
                        if (cursor >= 0 && cursor < workspace.controller.rows.length) {
                            const id = workspace.controller.rows[cursor].id;
                            Qt.callLater(function () {
                                workspace.openMessage(id);
                            });
                        }
                    }
                    section.property: "day"
                    section.criteria: ViewSection.FullString
                    section.delegate: K.TacitText {
                        required property string section
                        leftPadding: K.Kit.tokens.space.l
                        topPadding: K.Kit.tokens.space.s
                        bottomPadding: K.Kit.tokens.space.xs
                        text: section
                        size: "meta"
                        weight: "medium"
                        ink: "quiet"
                    }
                    delegate: MailMessagePreview {
                        id: preview
                        required property int index

                        controller: workspace.controller
                        width: mailList.rowWidth
                        ring: mailList.ringAt(index)
                        onRowClicked: modifiers => mailList.clickAt(index, modifiers)
                        onMessageRequested: messageId => workspace.openMessage(messageId)
                        onContextRequestedForMessage: (messageId, position) => {
                            workspace.controller.act("select", {
                                id: messageId
                            });
                            messageMenu.openAt(preview, position.x, position.y);
                        }
                    }
                }
            }
            K.PageState {
                visible: workspace.controller.rows.length === 0 && workspace.controller.ui.searching
                x: workspace.t.space.xxl
                y: mailList.y + workspace.t.space.xl
                maxWidth: inbox.width - workspace.t.space.page
                text: "No messages match your search."
                action: "Clear search"
                onActivated: workspace.controller.act("closeSearch")
            }
        }
        Item {
            id: reading
            readonly property real statusTop: workspace.t.height.header + workspace.t.space.xxl
            objectName: "readerPane"
            visible: !workspace.compact || workspace.compactReading
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: workspace.compact ? 0 : workspace.readerMinimum
            Layout.preferredWidth: workspace.t.width.list
            MailReader {
                id: reader
                visible: workspace.controller.ui.view !== "importing" && (!!workspace.controller.selected || ["draft", "compose"].includes(workspace.controller.ui.view))
                anchors.fill: parent
                controller: workspace.controller
                compact: workspace.compact
                onBackRequested: workspace.compactReading = false
                onAttachRequested: files.open()
            }
            Column {
                visible: workspace.controller.ui.view === "importing"
                x: reader.textX
                y: reading.statusTop
                width: reader.textWidth
                spacing: workspace.t.space.xl
                MailHeadline {
                    width: parent.width
                    text: qsTr("Getting your mail")
                }
                K.TacitText {
                    text: qsTr("%1 of %2 messages imported from Personal.")
                          .arg(workspace.controller.ui.imported.toLocaleString(Qt.locale(), "f", 0))
                          .arg((8600).toLocaleString(Qt.locale(), "f", 0))
                    ink: "sec"
                    width: parent.width
                    wrapMode: Text.Wrap
                }
                K.Progress {
                    width: parent.width
                    value: workspace.controller.ui.imported / 8600
                    label: "Importing mock mail"
                }
            }
            K.PageState {
                visible: !reader.visible && workspace.controller.ui.view !== "importing"
                x: reader.textX
                y: reading.statusTop
                maxWidth: reader.textWidth
                text: workspace.controller.rows.length ? qsTr("Choose a message to read.")
                    : workspace.controller.ui.folder === "Later"
                    ? qsTr("Nothing in Later. Mail you set aside returns to Inbox at the time you chose.")
                    : qsTr("Nothing in %1. Your messages will appear here.").arg(workspace.controller.ui.folder)
                action: qsTr("Back to Inbox")
                onActivated: workspace.controller.act("folder", {folder: "Inbox"})
            }
        }
    }
    MailSettings {
        visible: workspace.controller.ui.view === "settings"
        anchors.fill: parent
        controller: workspace.controller
    }
    MailAccountSetup {
        anchors.fill: parent
        visible: workspace.controller.ui.view === "setup"
        controller: workspace.controller
    }
    K.Menu {
        id: folderPicker
        items: ["Inbox", "Later", "Starred", "Drafts", "Sent", "Archive", "Junk", "Trash"].map(v => ({
                    label: v,
                    folder: v
                })).concat([
            {
                rule: true
            }
        ], workspace.controller.accounts.map(a => ({
                    label: a.name + " · " + a.email,
                    folder: "Inbox",
                    account: a.name
                })), [
            {
                rule: true
            },
            {
                label: "Add account",
                action: "setup"
            },
            {
                label: "Settings",
                action: "settings"
            }
        ])
        onPicked: i => {
            const entry = items[i];
            if (entry.action)
                workspace.controller.act(entry.action);
            else
                workspace.controller.act("folder", {
                    folder: entry.folder,
                    account: entry.account
                });
            workspace.compactReading = false;
        }
    }
    K.Menu {
        id: messageMenu
        items: [
            {
                label: "Reply"
            },
            {
                label: "Reply all"
            },
            {
                label: "Forward"
            },
            {
                label: "Mark unread"
            },
            {
                label: "Star"
            },
            {
                label: "Archive"
            },
            {
                label: "Move to Trash",
                risk: true
            }
        ]
        onPicked: i => {
            if (i < 3)
                workspace.controller.reply(items[i].label, false);
            else if (i === 3)
                workspace.controller.act("unread", {
                    value: true
                });
            else if (i === 4)
                workspace.controller.act("star");
            else
                workspace.controller.act("move", {
                    folder: i === 5 ? "Archive" : "Trash"
                });
        }
    }
    K.Notice {
        id: notice
        objectName: "mailNotice"
        onActivated: workspace.controller.act("undo")
        onClosed: if (workspace.controller.ui.notice === text)
            workspace.controller.act("clearNotice")
    }
    Connections {
        target: workspace.controller

        function onDataChanged() {
            if (workspace.controller.ui.notice && workspace.controller.ui.notice !== notice.text)
                notice.show(workspace.controller.ui.notice, workspace.controller.ui.undo ? "Undo" : "");
        }
    }
}
