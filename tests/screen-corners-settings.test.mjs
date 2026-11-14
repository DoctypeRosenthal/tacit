// The screen's corners in Settings > Desktop > Corners of the screen (#59): the top two corners open what is chosen for
// them, as the bottom two always did, and start as they were hard-wired (the palette, the notification centre); one
// switch turns the drawn rounding off. The four per-corner switches the pull request also had are left out (the owner,
// on the pull request: one switch and the two top-corner actions). ScreenCorners.qml's corner actions run under node
// through GlobalStates.toggleState on Config.qml's defaults, and the page's own rows on a settings object.
import { adapterDefaults, inScope, matchBrace, qmlFunction, qmlProperty, readExpression } from "./lib/qml.mjs";
import { check, done, read } from "./lib/check.mjs";

const defaults = () => adapterDefaults(read("modules/common/Config.qml"));
const corners = read("modules/ii/screenCorners/ScreenCorners.qml");
const Translation = { tr: s => s };
const list = inScope({ Translation }, "", `return (${qmlProperty(read("services/CornerActions.qml"), "list")});`)();

console.log("== what the top corners open (ScreenCorners.qml, GlobalStates.qml, Config.qml)");
const CornerEnum = { TopLeft: 0, TopRight: 1, BottomLeft: 2, BottomRight: 3 };
const toggle = qmlFunction(read("GlobalStates.qml"), "toggleState");
function press(corner, options) {
  const states = { hotCornerOptions: list };
  const IslandController = { ownsMedia: false, openMedia() {} };
  states.toggleState = inScope({ root: states, IslandController, console: { log() {} } }, toggle.params, toggle.body);
  const actions = inScope({ RoundCorner: { CornerEnum }, GlobalStates: states, Config: { options } }, "",
    `return (${qmlProperty(corners, "actionForCorner")});`)();
  actions[CornerEnum[corner]]();
  return Object.keys(states).filter(k => states[k] === true);
}
{
  const options = defaults();
  check("top left opens the palette, as it was hard-wired to", JSON.stringify(press("TopLeft", options)) === '["overviewOpen"]',
    JSON.stringify(press("TopLeft", options)));
  check("top right the notification centre", JSON.stringify(press("TopRight", options)) === '["notificationCenterOpen"]',
    JSON.stringify(press("TopRight", options)));
  options.sidebar.cornerOpen.topRightAction = "sidebarRightOpen";
  check("top right set to the control panel opens it", JSON.stringify(press("TopRight", options)) === '["sidebarRightOpen"]',
    JSON.stringify(press("TopRight", options)));
  options.sidebar.cornerOpen.topLeftAction = "none";
  check("top left set to None opens nothing", press("TopLeft", options).length === 0, JSON.stringify(press("TopLeft", options)));
  check("the bottom corners still open theirs", JSON.stringify(press("BottomRight", defaults())) === '["sidebarRightOpen"]');
}

console.log("== the corners' page (tacit-settings.qml)");
const src = read("tacit-settings.qml");
const groupAt = src.indexOf('title: "Corners of the screen"');
const open = src.lastIndexOf("Group {", groupAt) + "Group ".length;
const group = src.slice(open, matchBrace(src, open) + 1);
function row(label) {
  const at = group.indexOf(`label: "${label}"`);
  if (at < 0) return null;
  const start = Math.max(group.lastIndexOf("SwitchRow {", at), group.lastIndexOf("ChoiceRow {", at));
  const brace = group.indexOf("{", start);
  return { at: start, text: group.slice(brace, matchBrace(group, brace) + 1) };
}
const expr = (r, name) => { const m = new RegExp(`\\b${name}:`).exec(r.text); return m ? readExpression(r.text, m.index + m[0].length).expr : null; };
for (const [label, key] of [["Top left", "topLeftAction"], ["Top right", "topRightAction"]]) {
  const r = row(label);
  if (!r || !/^ChoiceRow/.test(group.slice(r.at))) { check(`${label} is a choice`, false, "no ChoiceRow"); continue; }
  const options = defaults();
  const value = e => inScope({ Config: { options }, CornerActions: { list } }, "", `return (${e});`)();
  check(`${label} offers what the bottom corners offer`, JSON.stringify(value(expr(r, "options")).map(o => o.value)) === JSON.stringify(list.map(o => o.value)));
  value(expr(r, "onPicked"))("wallpaperSelectorOpen");
  check(`and a pick is what it opens`, options.sidebar.cornerOpen[key] === "wallpaperSelectorOpen" && value(expr(r, "current")) === "wallpaperSelectorOpen",
    options.sidebar.cornerOpen[key]);
}
{
  const r = row("Round the screen corners");
  check("one switch for the drawn rounding", !!r);
  if (r) {
    const options = defaults();
    const value = e => inScope({ Config: { options } }, "", `return (${e});`)();
    check("on as Tacit starts (round when not fullscreen)", options.appearance.fakeScreenRounding === 2 && value(expr(r, "checked")) === true);
    value(expr(r, "onToggled"))(false);
    check("off: no rounding drawn", options.appearance.fakeScreenRounding === 0 && value(expr(r, "checked")) === false);
    // the corner strips' own binding, on what the switch wrote
    const shown = fullscreen => inScope({ Config: { options }, fullscreen }, "",
      `return (${qmlProperty(corners, "decorationVisible")});`)();
    check("and the corners draw none, fullscreen or not", !shown(false) && !shown(true));
    value(expr(r, "onToggled"))(true);
    check("on again: round unless fullscreen", options.appearance.fakeScreenRounding === 2 && shown(false) && !shown(true));
    check('"Use the corners" does not grey it out (it is how they look, not what they open)', expr(r, "enabled") === null, expr(r, "enabled"));
    const last = Math.max(...["Top left", "Top right", "Bottom left", "Bottom right"].map(l => row(l)?.at ?? -1));
    check("it comes after what the corners open, not between their switch and its rows", r.at > last);
  }
  check("no switch per corner", !/label: "Round the (top|bottom)/.test(group), (group.match(/label: "Round the (top|bottom)[^"]*"/g) ?? []).join(", "));
  check("nor a setting for one", !("shownScreenCorners" in defaults().appearance) && !corners.includes("shownScreenCorners"));
}
const categories = inScope({}, "", `return (${qmlProperty(read("services/SettingsCatalog.qml"), "categories")});`)();
const m = qmlFunction(src, "matches");
const found = query => categories.filter(cat => inScope({ root: { query } }, m.params, m.body)(cat)).map(c => c.key);
check('searching "rounded corners" finds Desktop', found("rounded corners").includes("desktop"), JSON.stringify(found("rounded corners")));
done();
