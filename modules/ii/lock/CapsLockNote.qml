import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * "Caps Lock is on" beside the password, for LockSurface and BootLockSurface. Hyprland does not announce
 * the lock keys, so the state is read from `hyprctl devices` (as the hyprlock this replaced did with
 * check-capslock.sh): when the lock opens, and after the Caps Lock key is pressed. Hidden when it cannot be read.
 */
RowLayout {
    id: root
    property bool on: false
    visible: on
    spacing: 4

    // the compositor sets the lock a moment after the key press reaches us
    function refresh() {
        settle.restart();
    }
    Component.onCompleted: refresh()

    Timer {
        id: settle
        interval: 80
        onTriggered: read.running = true
    }
    Process {
        id: read
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.on = JSON.parse(text)["keyboards"].find(kb => kb.main === true).capsLock === true;
                } catch (e) {
                    root.on = false; // hyprctl not up yet, or no main keyboard
                }
            }
        }
    }

    MaterialSymbol {
        text: "keyboard_capslock"
        iconSize: 20
        color: Appearance.colors.colSubtext
    }
    StyledText {
        text: Translation.tr("Caps Lock is on")
        font.pixelSize: 14
        color: Appearance.colors.colSubtext
    }
}
