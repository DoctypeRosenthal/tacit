import QtQuick
import qs

// Keeps the auto-hide bar of one screen shown while `holding`: a tray menu or popup hangs off the
// bar, and the pointer leaving the bar for it must not slide the bar away from under it.
QtObject {
    id: root
    property bool holding: false
    property string screenName: ""
    // the screen this hold was taken on, so it is given back there if the screen changes or goes
    property string heldName: ""

    function sync() {
        const want = root.holding && root.screenName !== "" ? root.screenName : "";
        if (want === root.heldName) return;
        if (root.heldName !== "") GlobalStates.releaseBar(root.heldName);
        root.heldName = want;
        if (want !== "") GlobalStates.holdBar(want);
    }

    onHoldingChanged: sync()
    onScreenNameChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (root.heldName !== "") GlobalStates.releaseBar(root.heldName);
    }
}
