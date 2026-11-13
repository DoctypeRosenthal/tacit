import QtQuick

QtObject {
    id: query

    property var client
    property string account
    property string folder
    property int revision: 0
    readonly property string key: client && folder ? JSON.stringify([account, folder]) : ""
    onKeyChanged: if (key) refresh()
    property var messages: []
    property bool loading: false
    property string error: ""

    signal refreshed(var messages)

    function refresh() {
        if (!client?.enabled || !folder)
            return;
        error = "";
        loading = true;
        client.loadMailbox(account, folder, ++revision);
    }

    property Connections responses: Connections {
        target: query.client
        function onMailboxLoaded(revision, messages, ok) {
            if (!query.folder || revision !== query.revision)
                return;
            query.loading = false;
            query.error = ok ? "" : qsTr("Could not load the local mailbox.");
            if (ok) {
                query.messages = messages;
                query.refreshed(messages);
            }
        }
        function onFailed() {
            query.loading = false;
            query.error = qsTr("Could not load the local mailbox.");
        }
    }
}
