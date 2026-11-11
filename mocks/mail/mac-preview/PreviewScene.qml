import QtQuick
import Tacit.Kit as K
import ".." as Mail

FocusScope {
    id: scene

    property string initialScreen: "read"
    property alias controller: model
    readonly property real groundRadius: K.Kit.tokens.radius.window
    focus: true

    Mail.MailState {
        id: model
        initialScreen: scene.initialScreen
        agentInk: K.Kit.tokens.accent
        onSettingsChanged: K.Kit.reducedMotion = settings.reducedMotion
    }

    K.WindowGround {
        anchors.fill: parent
        DragHandler {
            enabled: typeof previewWindow !== "undefined"
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            acceptedButtons: Qt.LeftButton
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            onActiveChanged: if (active) previewWindow.dragBackground()
        }
    }

    Mail.MailWorkspace {
        objectName: "mailScene"
        prewarmHtml: true
        anchors.fill: parent
        controller: model
    }

    function snapshot() { return JSON.stringify(model.data); }
    function restore(snapshot) { model.data = JSON.parse(snapshot); }

    function simulate(action) {
        if (action === "authorize")
            model.completeAuthorization("preview@example.test");
        else
            model.act(action);
    }
}
