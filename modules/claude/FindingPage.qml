import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * One finding on the Results trail: what it is and how bad, what the agent said, the fix it
 * proposed, what a checker made of it, the words of the report it comes from (a written report read
 * by Sonnet), the file and line, and the agents that reported it (each opens its page).
 */
PanelPage {
    id: fp
    bodyHeight: col.implicitHeight
    readonly property var p: fp.pane
    readonly property var f: fp.entry.f.finding ?? ({})
    readonly property var statusWord: ({ problem: "Problem", open: "Open", fixed: "Fixed", done: "Done", confirmed: "Confirmed", not_a_bug: "Not a bug" })
    // the report's file placed: an absolute path and line, or no path when the session's folder is not known
    readonly property var where: fp.p.fileOf(fp.f.files?.[0] ?? "", fp.f.line)
    readonly property string file: fp.where.path || String(fp.f.files?.[0] ?? "").replace(/:\d+(:\d+)?$/, "")
    readonly property string place: fp.file.split("/").pop() + (fp.where.line ? `:${fp.where.line}` : "")
    // a path the Files tab can open
    readonly property bool openable: fp.where.path.length > 0
    // how bad, in the words the list uses; the report's own rating follows when it says more
    readonly property string levelWord: ({ high: "High", medium: "Medium", low: "Low" })[fp.f.level ?? ""] ?? ""
    readonly property string severityWord: {
        const s = String(fp.f.severity ?? "").trim();
        return s.length && s.toLowerCase() !== fp.levelWord.toLowerCase() ? s : "";
    }

    // the keys: Up and Down move a cursor over the rows that open something, Enter opens it
    readonly property string cur: fp.entry.f.cursor ?? ""
    readonly property var navList: [...(fp.openable ? ["where"] : []),
        ...(fp.f.sources ?? []).filter(s => !!fp.p.findAgent(fp.p.info, s.source)).map(s => `src:${s.source}`)]
    function act(k) {
        if (k === "where") fp.openFile();
        else if (k.startsWith("src:")) fp.p.openAgent(k.slice(4));
    }
    function navKey(k) {
        const n = fp.navList.length;
        if (!n) return false;
        const at = fp.navList.indexOf(fp.cur);
        if (k === Qt.Key_Down || k === Qt.Key_Up) {
            fp.entry.f.cursor = fp.navList[Math.max(0, Math.min(n - 1, at < 0 ? 0 : at + (k === Qt.Key_Down ? 1 : -1)))];
            fp.entryChanged();
            return true;
        }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Right) && at >= 0) { fp.act(fp.navList[at]); return true; }
        return false;
    }
    function openFile() { if (fp.openable && fp.p.files) fp.p.files.openFile(fp.where.path, fp.where.line, ""); }

    component Words: StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        font.pixelSize: 16
        lineHeight: 1.3
        color: Appearance.colors.colInkMain
    }

    Column {
        id: col
        width: parent.width
        spacing: 2
        StyledText {
            width: parent.width
            topPadding: 4
            text: [fp.statusWord[fp.f.status] ?? "", fp.levelWord, fp.severityWord, fp.f.checked?.real ? "checked: real" : ""].filter(x => x).join(" · ")
            font.pixelSize: 14
            color: fp.f.level === "high" && fp.f.need === "look" ? Appearance.colors.colClay : Appearance.colors.colInkMeta
        }
        StyledText {
            width: parent.width
            topPadding: 2
            wrapMode: Text.Wrap
            text: fp.f.title ?? ""
            font.pixelSize: 22
            font.weight: Font.DemiBold
            lineHeight: 1.1
            color: Appearance.colors.colInkMain
        }
        // where and who, before the words: the file (it opens), the agent that reported it, its time
        Row {
            readonly property var a0: fp.p.findAgent(fp.p.info, fp.f.sources?.[0]?.source ?? "")
            topPadding: 6
            spacing: 6
            StyledText {
                visible: fp.file.length > 0
                text: fp.place
                font.pixelSize: 14
                color: fp.openable ? (whereArea.containsMouse ? Appearance.colors.colInkMain : Appearance.colors.colPrimary) : Appearance.colors.colInkSecondary
                MouseArea { id: whereArea; anchors.fill: parent; enabled: fp.openable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fp.openFile() }
            }
            StyledText {
                text: [fp.file.length ? "·" : "", fp.p.niceLabel(fp.f.sources?.[0]?.name ?? ""), parent.a0 ? `· ${fp.p.took(parent.a0)}` : ""].filter(x => x).join(" ")
                font.pixelSize: 14
                color: Appearance.colors.colInkSecondary
            }
        }
        Words { visible: (fp.f.detail ?? "").length > 0; topPadding: 12; text: fp.f.detail ?? "" }
        // its file was written after the report: it may be fixed
        StyledText {
            visible: !!fp.f.changedSince
            width: parent.width
            topPadding: 8
            wrapMode: Text.Wrap
            text: `The file changed on ${new Date(fp.f.changedSince ?? 0).toLocaleString(Qt.locale(), "d MMM, HH:mm")}, after this was reported. It may be fixed.`
            font.pixelSize: 14
            color: Appearance.colors.colPrimary
        }

        PanelSection { topPadding: 22; visible: (fp.f.fix ?? "").length > 0; text: "Fix" }
        Words { visible: (fp.f.fix ?? "").length > 0; text: fp.f.fix ?? "" }

        PanelSection { topPadding: 22; visible: !!fp.f.checked; text: "Checked" }
        Words {
            visible: !!fp.f.checked
            text: [fp.f.checked?.real ? "Real" : "Not real", fp.f.checked?.verdict ?? "", fp.f.checked?.severity ? `should be ${fp.f.checked.severity}` : ""].filter(x => x).join(" · ")
                  + (fp.f.checked?.why ? `\n${fp.f.checked.why}` : "")
        }

        PanelSection { topPadding: 22; visible: (fp.f.quote ?? "").length > 0; text: "From the report, read by Sonnet" }
        Rectangle {
            visible: (fp.f.quote ?? "").length > 0
            width: parent.width
            height: quote.implicitHeight + 20
            radius: 10
            color: ColorUtils.transparentize(Appearance.m3colors.m3onSurface, 0.95)
            StyledText {
                id: quote
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                wrapMode: Text.Wrap
                text: `“${fp.f.quote ?? ""}”`
                font.pixelSize: 15
                color: Appearance.colors.colInkSecondary
            }
        }

        PanelSection { topPadding: 22; visible: fp.file.length > 0; text: "Where" }
        PanelRow {
            id: whereRow
            visible: fp.file.length > 0
            glyph: "description"
            cursor: fp.cur === "where"
            onCursorChanged: if (cursor) fp.reveal(whereRow)
            title: fp.place
            line: fp.file.split("/").slice(0, -1).join("/")
            chevron: fp.openable
            onClicked: fp.act("where")
        }

        PanelSection { topPadding: 22; visible: (fp.f.sources ?? []).length > 0; text: (fp.f.sources ?? []).length === 1 ? "Reported by" : `Reported by ${(fp.f.sources ?? []).length} agents` }
        Repeater {
            model: fp.f.sources ?? []
            PanelRow {
                id: srcRow
                required property var modelData
                readonly property var a: fp.p.findAgent(fp.p.info, modelData.source)
                cursor: fp.cur === `src:${modelData.source}`
                onCursorChanged: if (cursor) fp.reveal(srcRow)
                mark: a?.state ?? "done"
                title: fp.p.niceLabel(modelData.name)
                line: a ? fp.p.lineOf(a) : ""
                meta: a ? fp.p.took(a) : ""
                chevron: !!a
                onClicked: if (a) fp.act(`src:${modelData.source}`)
            }
        }
    }
}
