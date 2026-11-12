pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    required property Component contentComponent

    // Kept up for 450 ms after the request ends, so the content can fold back instead of vanishing.
    property bool lingering: false

    // The monitor that takes the keys, fixed when the request starts so the typed password stays on
    // one surface even if the pointer moves to another screen meanwhile.
    property string keyScreenName: ""
    function pickKeyScreen() {
        root.keyScreenName = WM.compositor === "niri"
            ? (NiriBackend.focusedMonitor?.name ?? "")
            : (Hyprland.focusedMonitor?.name ?? "");
    }
    Component.onCompleted: if (PolkitService.active) root.pickKeyScreen()

    Connections {
        target: PolkitService
        function onActiveChanged() {
            if (PolkitService.active) {
                root.pickKeyScreen();
            } else {
                root.lingering = true;
                linger.restart();
            }
        }
    }
    Timer {
        id: linger
        interval: 450
        onTriggered: root.lingering = false
    }

    Loader {
        active: PolkitService.active || root.lingering
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData
                
                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:polkit"
                // Exclusive while asking: with OnDemand the keys went to the focused window until
                // the prompt was clicked, so the password was typed into the terminal. Only the focused
                // monitor's surface asks for them (the first screen if none matches): with every
                // surface exclusive the compositor picked one, maybe on the screen nobody looks at.
                readonly property bool takesKeys: Quickshell.screens.some(s => s.name === root.keyScreenName)
                    ? panelWindow.screen?.name === root.keyScreenName
                    : panelWindow.screen === Quickshell.screens[0]
                WlrLayershell.keyboardFocus: PolkitService.active && panelWindow.takesKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.contentComponent
                }
            }
        }
    }
}
