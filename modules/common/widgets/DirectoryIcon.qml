import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

Image {
    id: root
    required property var fileModelData
    asynchronous: true
    fillMode: Image.PreserveAspectFit

    source: {
        if (!fileModelData.fileIsDir)
            return Quickshell.iconPath("application-x-zerosize");

        // the icon follows which standard folder it is, not what the folder is called (~/Dokumente is Documents)
        const standardFolder = [[Directories.documents, "documents"], [Directories.downloads, "downloads"], [Directories.music, "music"], [Directories.pictures, "pictures"], [Directories.videos, "videos"]]
            .find(entry => FileUtils.trimFileProtocol(entry[0]) === fileModelData.filePath);
        if (standardFolder)
            return Quickshell.iconPath(`folder-${standardFolder[1]}`, "inode-directory");

        return Quickshell.iconPath("inode-directory");
    }

    onStatusChanged: {
        if (status === Image.Error)
            source = Quickshell.iconPath("error");
    }

    Process {
        running: !fileModelData.fileIsDir
        command: ["file", "--mime", "-b", fileModelData.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.split(";")[0].replace("/", "-");
                root.source = Images.validImageTypes.some(t => mime === `image-${t}`) ? fileModelData.fileUrl : Quickshell.iconPath(mime, "image-missing");
            }
        }
    }
}
