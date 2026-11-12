pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool packageManagerRunning: false
    property bool downloadRunning: false

    // said when both looks below have come back (a caller that acts on the answer waits for it)
    signal checked()
    property int pending: 0
    function settle() {
        root.pending = Math.max(0, root.pending - 1);
        if (root.pending === 0)
            root.checked();
    }

    function refresh() {
        pending = 2;
        packageManagerRunning = false;
        downloadRunning = false;
        detectPackageManagerProc.running = false;
        detectPackageManagerProc.running = true;
        detectDownloadProc.running = false;
        detectDownloadProc.running = true;
    }

    Process {
        id: detectPackageManagerProc
        command: ["bash", "-c", "pidof yay paru dnf zypper apt apx xbps snap apk yum epsi pikman || ls /var/lib/pacman/db.lck"]
        onExited: (exitCode, exitStatus) => {
            root.packageManagerRunning = (exitCode === 0);
            root.settle();
        }
    }

    Process {
        id: detectDownloadProc
        // Not `pidof curl wget`: any health check, script or agent satisfied that, and a
        // warning row that cries wolf teaches the user to ignore the one beside it. A partial
        // file in the downloads folder, or one of the two tools that only ever download.
        command: ["bash", "-c", "pidof aria2c yt-dlp || find \"$1\" -maxdepth 1 -type f \\( -name '*.part' -o -name '*.crdownload' \\) -print -quit | grep -q .",
                  "_", FileUtils.trimFileProtocol(Directories.downloads)]
        onExited: (exitCode, exitStatus) => {
            root.downloadRunning = (exitCode === 0);
            root.settle();
        }
    }
}
