import QtQuick

QtObject {
    id: query

    property var client
    property string term
    property bool active: false
    readonly property string requestKey: client && active ? JSON.stringify(term) : ""
    property int revision: 0
    property bool loading: false
    signal completed(var messages, bool ok)

    onRequestKeyChanged: {
        ++revision;
        delay.stop();
        loading = requestKey !== "";
        if (loading)
            delay.restart();
    }

    property Timer delay: Timer {
        interval: 200
        onTriggered: query.client.search(query.term, query.revision)
    }

    property Connections responses: Connections {
        target: query.client
        function onSearched(revision, messages, ok) {
            if (revision !== query.revision || !query.active)
                return;
            query.loading = false;
            query.completed(messages, ok);
        }
    }
}
