import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    readonly property bool clickToShow: Config.options.bar.tooltips.clickToShow
    // Hover shows it while the pointer is over the widget. With click to show the pointer is not
    // tracked (a MouseArea without hover says "contains" only while a button is down), so a click
    // latches it and it stays until a click elsewhere or Esc (see the window below).
    active: hoverTarget && (clickToShow ? GlobalStates.latchedPopup === root : hoverTarget.containsMouse)

    readonly property QtObject clickWatch: Connections {
        target: root.clickToShow ? root.hoverTarget : null
        function onClicked(mouse) {
            if (mouse.button !== Qt.LeftButton) return;
            GlobalStates.latchedPopup = GlobalStates.latchedPopup === root ? null : root;
        }
    }

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real barThickness: barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight

    component: PanelWindow {
        id: popupWindow

        // The window exists only while the popup is shown: it keeps an auto-hide bar shown, since a
        // popup opened by a click outlives the pointer's stay on the bar.
        BarHold {
            holding: true
            screenName: popupWindow.screen?.name ?? ""
        }

        // Click to show: the one dismissal rule, a click elsewhere or Esc lets the popup go. The
        // bar is in the grab, so a click on the widget itself still toggles it.
        Component.onCompleted: {
            if (root.clickToShow) GlobalFocusGrab.addDismissable(popupWindow);
        }
        Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)
        Connections {
            target: GlobalFocusGrab
            enabled: root.clickToShow
            function onDismissed() { GlobalStates.latchedPopup = null; }
        }
        Connections {
            target: IslandController
            enabled: root.clickToShow
            function onCollapseExpansion() { GlobalStates.latchedPopup = null; }
        }

        // Bring contentItem reference into this scope
        property Item innerContent: root.contentItem

        // on the monitor of the bar that is hovered, so the edge clamp below uses that screen's size
        screen: root.hoverTarget?.QsWindow.window?.screen ?? null
        color: "transparent"
        anchors.left: root.barEdge !== "right"
        anchors.right: root.barEdge === "right"
        anchors.top: root.barEdge !== "bottom"
        anchors.bottom: root.barEdge === "bottom"

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        readonly property real centerOffsetX: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
            ).x ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxLeft = popupWindow.screen.width - popupBackground.implicitWidth - margin - 10
            return Math.max(margin, Math.min(base, maxLeft))
        }
        readonly property real centerOffsetY: {
            const base = root.QsWindow?.mapFromItem(
                root.hoverTarget,
                0, (root.hoverTarget.height - popupBackground.implicitHeight) / 2
            ).y ?? 0
            const margin = Appearance.sizes.elevationMargin
            const maxTop = popupWindow.screen.height - popupBackground.implicitHeight - margin - 15
            return Math.max(margin, Math.min(base, maxTop))
        }

        mask: Region {
            item: popupBackground
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (root.barEdge === "right") return 0
                if (root.barEdge === "left") return root.barThickness
                return centerOffsetX 
            }
            top: {
                if (root.barEdge === "bottom") return 0
                if (root.barEdge === "top") return root.barThickness
                return centerOffsetY
            }
            right: root.barEdge === "right" ? root.barThickness : 0
            bottom: root.barEdge === "bottom" ? root.barThickness : 0
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 8

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }

            // Use local reference instead of crossing LazyLoader scope boundary
            implicitWidth: (popupWindow.innerContent?.implicitWidth ?? 0) + margin * 2
            implicitHeight: (popupWindow.innerContent?.implicitHeight ?? 0) + margin * 2

            color: Appearance.colors.colLayer1Base
            radius: Appearance.rounding.normal + 4
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            // Reparent content here once the window is ready
            Component.onCompleted: {
                if (popupWindow.innerContent) {
                    popupWindow.innerContent.parent = popupBackground
                    popupWindow.innerContent.anchors.centerIn = popupBackground
                }
            }
        }
    }
}