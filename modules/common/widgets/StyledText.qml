import qs.modules.common
import QtQuick

Text {
    id: root
    property bool animateChange: false
    property real animationDistanceX: 0
    property real animationDistanceY: 6

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    property var defaultFont: shouldUseNumberFont ? Appearance.font.family.numbers : Appearance.font.family.main
    
    font {
        // Letters exactly as designed, nothing snapped to pixels: the macOS recipe with grey edges and the patched
        // Qt Quick that blends edges in linear light (~/dev/tacit-text; owner's pick 2026-10-02)
        hintingPreference: Font.PreferNoHinting
        family: defaultFont
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        // Both families are variable, so both take their axis. Passing {} for numbers
        // meant Appearance.font.variableAxes.numbers was declared and never applied.
        variableAxes: shouldUseNumberFont ? Appearance.font.variableAxes.numbers : Appearance.font.variableAxes.main
    }
    color: Appearance?.m3colors.m3onBackground ?? "black"
    linkColor: Appearance?.m3colors.m3primary

    // The slide moves a transform, not x/y: those belong to the layout or anchors (centerIn), which
    // may still be changing when the text does, so an animation of them ends at a stale spot.
    transform: Translate { id: slide }

    component Anim: NumberAnimation {
        duration: 300 / 2
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    Behavior on text {
        id: textAnimationBehavior
        enabled: root.animateChange

        SequentialAnimation {
            alwaysRunToEnd: true
            ParallelAnimation {
                Anim {
                    target: slide
                    property: "x"
                    to: -root.animationDistanceX
                    easing.type: Easing.InSine
                }
                Anim {
                    target: slide
                    property: "y"
                    to: -root.animationDistanceY
                    easing.type: Easing.InSine
                }
                Anim {
                    target: root
                    property: "opacity"
                    to: 0
                    easing.type: Easing.InSine
                }
            }
            PropertyAction {} // Tie the text update to this point (we don't want it to happen during the first slide+fade)
            PropertyAction {
                target: slide
                property: "x"
                value: root.animationDistanceX
            }
            PropertyAction {
                target: slide
                property: "y"
                value: root.animationDistanceY
            }
            ParallelAnimation {
                Anim {
                    target: slide
                    property: "x"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    target: slide
                    property: "y"
                    to: 0
                    easing.type: Easing.OutSine
                }
                Anim {
                    target: root
                    property: "opacity"
                    to: 1
                    easing.type: Easing.OutSine
                }
            }
        }
    }
}
