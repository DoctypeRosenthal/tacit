import QtQuick
import Tacit.Kit as K

Item {
    id: body
    property bool expanded: true
    default property alias contents: content.data
    width: parent.width
    height: expanded ? content.height : 0
    visible: height > 0
    clip: true
    Behavior on height {
        NumberAnimation {
            duration: K.Kit.ms(body.expanded ? K.Kit.motion("arriveSmall").ms : K.Kit.motion("leave").ms)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: body.expanded ? K.Kit.motion("arriveSmall").curve : K.Kit.motion("leave").curve
        }
    }
    Column {
        id: content
        width: parent.width
        spacing: 0
    }
}
