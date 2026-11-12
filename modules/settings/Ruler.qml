import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * A continuous amount as Praxis's slim bar (the workflow lanes' 6 px track): the reached part in
 * the secondary ink, a knob only under the pointer or while dragged, the value as a word at the end.
 * TacitSlider's interface (value, pressed, moved, label), so a row swaps one for the other; the
 * shell's own sliders stay TacitSlider.
 */
Slider {
    id: ruler
    property string label: ""
    property bool fill: false           // as wide as its place (a stacked row, a summary)
    readonly property real wordArea: ruler.label.length > 0 ? 72 : 0
    implicitWidth: 260
    width: ruler.fill && parent ? parent.width : implicitWidth
    implicitHeight: 28
    padding: 0
    rightPadding: ruler.wordArea
    live: true

    // Said once a value is chosen: on release, and once the keys (arrows, Page Up/Down, Home/End) have rested. A row
    // that wrote on release alone never heard of a value set from the keyboard: the bar moved and nothing was saved.
    signal settled()
    onPressedChanged: if (!ruler.pressed) ruler.settled()
    onMoved: if (!ruler.pressed) keysRest.restart()
    Timer {
        id: keysRest
        interval: 350
        onTriggered: ruler.settled()
    }

    background: Item {
        x: ruler.leftPadding
        width: ruler.availableWidth
        height: ruler.height
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.88)
            Rectangle {
                width: Math.max(6, parent.width * ruler.visualPosition)
                height: parent.height
                radius: 3
                color: ruler.enabled ? Tacit.inkSec : Appearance.colors.colInkFaint
            }
        }
    }
    handle: Rectangle {
        x: ruler.leftPadding + ruler.visualPosition * (ruler.availableWidth - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Appearance.colors.colInkMain
        // and while it has the keyboard's focus, so a Tab to it shows where it is
        opacity: ruler.enabled && (ruler.hovered || ruler.pressed || ruler.visualFocus) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 110 } }
    }

    StyledText {
        visible: ruler.label.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: ruler.wordArea - 12
        horizontalAlignment: Text.AlignRight
        text: ruler.label
        font.pixelSize: 15
        font.features: { "tnum": 1 }
        color: Tacit.inkSec
        elide: Text.ElideRight
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: ruler.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }
}
