import QtQuick
import Tacit.Kit as K

Item {
    id: body

    property alias text: input.text
    readonly property alias input: input
    readonly property var t: K.Kit.tokens
    signal edited()
    signal submitted()
    signal dismissed()

    implicitHeight: 8 * metrics.lineSpacing + 2 * t.space.s

    function focusIn() { input.forceActiveFocus(); }

    FontMetrics {
        id: metrics
        font: input.font
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.topMargin: body.t.space.s
        anchors.bottomMargin: body.t.space.s
        contentWidth: width
        contentHeight: input.contentHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: true

        TextEdit {
            id: input
            width: scroll.width
            height: Math.max(contentHeight, scroll.height)
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            activeFocusOnTab: true
            font: placeholder.font
            renderType: placeholder.renderType
            color: body.t.inkMain
            selectionColor: Qt.alpha(body.t.accent, 0.4)
            selectedTextColor: body.t.inkMain
            cursorDelegate: Rectangle {
                width: 1.5
                color: body.t.accent
                visible: input.cursorVisible
            }
            Accessible.role: Accessible.EditableText
            Accessible.name: qsTr("Message body")
            Accessible.multiLine: true
            onTextChanged: body.edited()
            onCursorRectangleChanged: {
                const caret = cursorRectangle;
                if (caret.y < scroll.contentY)
                    scroll.contentY = caret.y;
                else if (caret.y + caret.height > scroll.contentY + scroll.height)
                    scroll.contentY = caret.y + caret.height - scroll.height;
            }
            Keys.onPressed: event => {
                K.Kit.focusVisible = true;
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    && (event.modifiers & Qt.ControlModifier)) {
                    body.submitted();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    body.dismissed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    const forward = event.key === Qt.Key_Tab;
                    input.nextItemInFocusChain(forward)?.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                    event.accepted = true;
                }
            }
        }
    }

    K.TacitText {
        id: placeholder
        y: body.t.space.s
        width: body.width
        text: qsTr("Write your message")
        size: "body"
        ink: "quiet"
        visible: input.text === "" && input.preeditText === ""
        Accessible.ignored: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: input.activeFocus && K.Kit.focusVisible ? body.t.accent : Qt.alpha(body.t.inkMain, body.t.wash.current)
        Accessible.ignored: true
    }

    HoverHandler { cursorShape: Qt.IBeamCursor }
}
