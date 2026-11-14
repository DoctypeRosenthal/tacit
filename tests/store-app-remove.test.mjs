// Remove on an app's own page in Apps (store.qml, #54): "On this computer · Remove" under its capsule, only for what Apps
// got itself (the backend's removable, scripts/store/stored.py info), waiting while another app is got or removed, and
// gone while it is removed and once it is. The page's own bindings under node, on the backend's facts for GIMP installed
// with pacman and an app got here as a bundle (tests/lib/store_cases.py yours).
import { spawnSync } from "child_process";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { inScope, matchBrace, qmlFunction, readExpression } from "./lib/qml.mjs";
import { check, done, read, tree } from "./lib/check.mjs";

const r = spawnSync("python3", ["-I", join(dirname(fileURLToPath(import.meta.url)), "lib", "store_cases.py"), tree, "yours"], { encoding: "utf8" });
if (r.status !== 0) throw new Error(r.stderr);
const { pacman, bundle } = JSON.parse(r.stdout);
const qml = read("store.qml");

// the column under the app page's capsule, and in it each item's bindings
const colAt = qml.indexOf("{", qml.lastIndexOf("Column {", qml.indexOf("id: getCol")));
const col = qml.slice(colAt, matchBrace(qml, colAt) + 1);
function item(type, has) {
  for (let i = col.indexOf(`${type} {`); i >= 0; i = col.indexOf(`${type} {`, i + 1)) {
    const open = col.indexOf("{", i), text = col.slice(open, matchBrace(col, open) + 1);
    if (text.includes(has)) return text;
  }
  return null;
}
function binding(text, name) {
  if (!text) return null;
  const m = new RegExp(`(^|[{;\\s])${name}\\s*:`).exec(text);
  return m ? readExpression(text, m.index + m[0].length).expr : null;
}
const removeWord = item("Word", 'text: "Remove"');
const line = item("Row", "On this computer");
const caption = item("Small", "It's in your apps now.");

const stateOf = qmlFunction(qml, "stateOf");
function page(a, root) {
  Object.assign(root, { settled: root.settled ?? {}, justGot: root.justGot ?? "", work: root.work ?? null,
    appOf: p => ({ gimp: pacman, krita: bundle })[p] ?? null });
  root.stateOf = inScope({ root, ...root }, stateOf.params, stateOf.body);
  const scope = { root, appPage: { a, st: root.stateOf(a) } };
  const at = (text, name, otherwise) => { const e = binding(text, name); return e === null ? otherwise : inScope(scope, "", `return (${e});`)(); };
  return {
    line: !!line && at(line, "visible", true),
    remove: !!removeWord && at(line, "visible", true) && !!at(removeWord, "visible", true),
    removable: !!removeWord && !!at(removeWord, "enabled", true),
    caption: at(caption, "visible", true) ? at(caption, "text", "") : "",
  };
}

console.log("== Remove on an app's page (store.qml)");
const got = page(bundle, {});
check("an app Apps got: On this computer · Remove under its capsule", got.line && got.remove && got.removable, JSON.stringify(got));
check("and the caption does not say On this computer a second time", got.caption === "", `"${got.caption}"`);
const byHand = page(pacman, {});
check("GIMP installed with pacman: On this computer, and no Remove", byHand.line && !byHand.remove, JSON.stringify(byHand));
const busy = page(bundle, { work: { pkg: "gimp", kind: "install", progress: 0.3, phase: "Downloading" } });
check("while another app is got, Remove is there but waits (a press would be dropped)", busy.remove && !busy.removable, JSON.stringify(busy));
const removing = page(bundle, { work: { pkg: "krita", kind: "remove", progress: 0.5, phase: "Removing" } });
check("while it is removed: neither the line nor a caption (the capsule says Removing)", !removing.line && removing.caption === "",
  JSON.stringify(removing));
const justGot = page(bundle, { justGot: "krita" });
check("just got: It's in your apps now., not the line", !justGot.line && justGot.caption === "It's in your apps now.", JSON.stringify(justGot));
// removed, before the lists are read again: the window's settled says so (store-just-got.test.mjs)
const gone = page(Object.assign({}, bundle, { plan: { appMB: 240 } }), { settled: { krita: false } });
check("removed: no Remove left, and the caption is what it costs again", !gone.line && /^240 MB · Free/.test(gone.caption), JSON.stringify(gone));
done();
