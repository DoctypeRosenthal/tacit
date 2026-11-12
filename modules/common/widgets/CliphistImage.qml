import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property string entry
    property real maxWidth
    property real maxHeight
    property bool blur: false
    property string blurText: "Image hidden"

    property string imageDecodePath: Directories.cliphistDecode
    // One decoded file per preview, not per cliphist entry: the same entry is shown by several
    // previews at once (launcher and palette), and a preview that went away used to delete the
    // file the live ones were reading.
    readonly property string instanceTag: Math.random().toString(36).slice(2, 10)
    property string imageDecodeFileName: `${entryNumber}-${instanceTag}`
    property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
    property string source

    property int entryNumber: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/^(\d+)\t/);
        return match ? parseInt(match[1]) : 0;
    }
    property int imageWidth: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    property int imageHeight: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/(\d+)x(\d+)/);
        return match ? parseInt(match[2]) : 0;
    }
    property real scale: {
        return Math.min(root.maxWidth / imageWidth, root.maxHeight / imageHeight, 1);
    }

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small
    implicitHeight: imageHeight * scale
    implicitWidth: imageWidth * scale

    Component.onCompleted: {
        root.decode();
    }

    // A preview can be given another entry (the search list reuses its rows): decode the new one
    // and drop the old file
    onImageDecodeFilePathChanged: {
        if (decodeImageProcess.outPath.length > 0)
            root.decode();
    }

    function decode() {
        // A decode in progress comes back here from its exit, once it sees the entry moved on
        if (decodeImageProcess.running)
            return;
        root.removeDecoded();
        decodeImageProcess.outPath = root.imageDecodeFilePath;
        decodeImageProcess.decodeEntry = root.entry;
        root.source = "";
        decodeImageProcess.running = true;
    }

    function removeDecoded() {
        const path = decodeImageProcess.outPath;
        if (path.length > 0)
            Quickshell.execDetached(["bash", "-c", `[ -f '${path}' ] && rm -f '${path}'`]);
    }

    Process {
        id: decodeImageProcess
        property string outPath: ""
        property string decodeEntry: ""
        // -s, so a decode that wrote nothing is not handed to the Image as a valid picture
        command: ["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(decodeEntry)}' | ${Cliphist.cliphistBinary} decode > '${outPath}' && [ -s '${outPath}' ]`]
        onExited: (exitCode, exitStatus) => {
            if (outPath !== root.imageDecodeFilePath) {
                root.decode();
            } else if (exitCode === 0) {
                root.source = outPath;
            } else {
                console.error("[CliphistImage] Failed to decode image for entry:", decodeEntry);
                root.source = "";
            }
        }
    }

    Component.onDestruction: root.removeDecoded()

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: image.width
            height: image.height
            radius: root.radius
        }
    }

    StyledImage {
        id: image
        anchors.fill: parent

        source: Qt.resolvedUrl(root.source)
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        asynchronous: true

        width: root.imageWidth * root.scale
        height: root.imageHeight * root.scale
        sourceSize.width: width
        sourceSize.height: height
    }

    Loader {
        id: blurLoader
        active: root.blur
        anchors.fill: image
        sourceComponent: GaussianBlur {
            source: image
            radius: 35
            samples: radius * 2 + 1

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.5)

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    MaterialSymbol {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "visibility_off"
                        font.pixelSize: 28
                    }
                    StyledText {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.blurText
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.smallie
                    }
                }
            }
        }
    }
}
