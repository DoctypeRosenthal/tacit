pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Process {
    id: proc

    signal finished(string output)

    property list<var> sequence: []
    property int index: 0
    // A sequence asked for while another one's process is still running waits for that process to
    // end. Quickshell ends it with its stream first (carrying the old output), then exited, and only
    // then starts the next command, so the old output has to be dropped or it would be taken for the
    // new sequence's first step and the new first command would never run.
    property var pendingSequence: null
    property bool dropOutput: false

    // Runs a sequence of command and functions
    function runSequence(seq) {
        if (seq.length == 0)
            return;
        if (running) {
            pendingSequence = seq;
            dropOutput = true;
            running = false;
            return;
        }
        sequence = seq;
        index = -1;
        step();
    }

    function step(output) {
        index++;
        if (index >= sequence.length) {
            finished(output);
            return;
        }
        const nextItem = sequence[index];
        if (typeof nextItem === "function") {
            const nextOutput = nextItem(output);
            step(nextOutput);
        } else {
            // If empty command then not set; this allows setting it with previous function
            if (nextItem.length > 0)
                command = nextItem;
            running = true;
        }
    }

    // The process is gone: start the sequence that was waiting for it (also when it never started,
    // which sends no stream and no exit).
    onRunningChanged: {
        if (running)
            return;
        dropOutput = false;
        if (pendingSequence !== null) {
            const seq = pendingSequence;
            pendingSequence = null;
            runSequence(seq);
        }
    }

    stdout: StdioCollector {
        onStreamFinished: {
            if (proc.dropOutput) {
                proc.dropOutput = false;
                return;
            }
            proc.step(text);
        }
    }
}
