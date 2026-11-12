import qs.modules.common
import qs.services
import "layouts.js" as Layouts
import QtQuick
import QtQuick.Layouts

Item {
    id: root    
    property var layouts: Layouts.byName
    // The keys send scancodes, so what they type is the compositor's layout: label them with it when layouts.js has
    // it (the config value is only written on a layout change, not for the one active at start), else the config's
    property var activeLayoutName: layouts.hasOwnProperty(HyprlandXkb.currentLayoutName) ? HyprlandXkb.currentLayoutName
        : (layouts.hasOwnProperty(Config.options?.osk.layout)) 
        ? Config.options?.osk.layout 
        : Layouts.defaultLayout
    property var currentLayout: layouts[activeLayoutName]

    implicitWidth: keyRows.implicitWidth
    implicitHeight: keyRows.implicitHeight

    ColumnLayout {
        id: keyRows
        anchors.fill: parent
        spacing: 5

        Repeater {
            model: root.currentLayout.keys

            delegate: RowLayout {
                id: keyRow
                required property var modelData
                spacing: 5
                
                Repeater {
                    model: modelData
                    // A normal key looks like this: {label: "a", labelShift: "A", shape: "normal", keycode: 30, type: "normal"}
                    delegate: OskKey { 
                        required property var modelData
                        keyData: modelData
                    }
                }
            }
        }
    }
}
