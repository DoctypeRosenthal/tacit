// The Tacit theme for Zed (contrib/zed, #65), installed and taken out in a home of its own with systemctl stood in for:
// install.sh copies what it says from a checkout, makes the theme, and sets a path unit on the files the generator reads
// (no service that wakes every 5 s), an earlier version's watcher is taken out, and uninstall.sh leaves only the theme.
// Then the generator itself: every colour from the wallpaper's palette, the see-through setting followed, and Tacit.json
// never left empty or half written for Zed, which reloads it as soon as it changes.
import { spawnSync } from "child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { check, done, read, tree } from "./lib/check.mjs";

const dir = join(tree, "contrib/zed");
const sandbox = mkdtempSync(join(tmpdir(), "tacit-zed-"));
const home = join(sandbox, "home"), stub = join(sandbox, "bin"), calls = join(sandbox, "systemctl.log");
const state = join(home, ".local/state/quickshell/user/generated"), config = join(home, ".config");
mkdirSync(state, { recursive: true }); mkdirSync(join(config, "illogical-impulse"), { recursive: true }); mkdirSync(stub);
writeFileSync(join(stub, "systemctl"), `#!/bin/sh\necho "$*" >> '${calls}'\n`); chmodSync(join(stub, "systemctl"), 0o755);
// a palette with matugen's roles (colors.json), one made-up colour each
const roles = ("background error error_container inverse_on_surface inverse_primary inverse_surface on_background on_error " +
  "on_error_container on_primary on_primary_container on_primary_fixed on_primary_fixed_variant on_secondary on_secondary_container " +
  "on_secondary_fixed on_secondary_fixed_variant on_surface on_surface_variant on_tertiary on_tertiary_container on_tertiary_fixed " +
  "on_tertiary_fixed_variant outline outline_variant primary primary_container primary_fixed primary_fixed_dim scrim secondary " +
  "secondary_container secondary_fixed secondary_fixed_dim shadow surface surface_bright surface_container surface_container_high " +
  "surface_container_highest surface_container_low surface_container_lowest surface_dim surface_tint surface_variant tertiary " +
  "tertiary_container tertiary_fixed tertiary_fixed_dim").split(" ");
const palette = seed => Object.fromEntries(roles.map((r, i) => [r, "#" + [0, 1, 2].map(k => ((seed * 37 + i * 53 + k * 91) % 200 + 40)
  .toString(16).padStart(2, "0")).join("")]));
writeFileSync(join(state, "colors.json"), JSON.stringify(palette(1)));
writeFileSync(join(config, "illogical-impulse/config.json"), JSON.stringify({ appearance: { transparency: { enable: false } } }));
const env = { HOME: home, PATH: `${stub}:/usr/bin:/bin` };
const run = (script, cwd = sandbox) => spawnSync("bash", [join(dir, script)], { cwd, env, encoding: "utf8" });
const log = () => (existsSync(calls) ? readFileSync(calls, "utf8") : "");
const units = join(config, "systemd/user"), scripts = join(config, "zed/scripts"), theme = join(config, "zed/themes/Tacit.json");

console.log("== installing the Zed theme from a checkout (contrib/zed/install.sh)");
// an earlier version's watcher, running
mkdirSync(units, { recursive: true }); mkdirSync(scripts, { recursive: true });
writeFileSync(join(units, "zed-tacit-theme-watch.service"), "[Service]\nExecStart=%h/.config/zed/scripts/zed-tacit-watch.sh\nRestart=always\n");
writeFileSync(join(scripts, "zed-tacit-watch.sh"), "#!/bin/sh\n");
const inst = existsSync(join(dir, "install.sh")) ? run("install.sh") : { status: "missing", stdout: "", stderr: "no contrib/zed/install.sh" };
check("it runs to the end from outside its folder", inst.status === 0, `exit ${inst.status}: ${inst.stderr.trim().split("\n").pop()}`);
check("install.sh and uninstall.sh can be run as they are", ["install.sh", "uninstall.sh"].every(f => existsSync(join(dir, f)) && statSync(join(dir, f)).mode & 0o100));
check("the generator is in place and runs", existsSync(join(scripts, "zed-tacit-theme.sh")) && statSync(join(scripts, "zed-tacit-theme.sh")).mode & 0o100);
let made = null;
try { made = JSON.parse(readFileSync(theme, "utf8")); } catch (e) {}
check("and has made the theme", made?.themes?.[0]?.name === "Tacit", existsSync(theme) ? "Tacit.json is not the theme" : "no Tacit.json");
check("the path unit is enabled, nothing else started", /^--user enable --now zed-tacit-theme\.path$/m.test(log()) && !/(restart|start) zed-tacit-theme-watch/.test(log()), log());
check("the old watcher is stopped and gone", /disable --now zed-tacit-theme-watch\.service/.test(log())
  && !existsSync(join(units, "zed-tacit-theme-watch.service")) && !existsSync(join(scripts, "zed-tacit-watch.sh")));

// the units, with systemd's own specifiers for a user manager: %S the state folder, %E the config folder
const spec = s => s.replace(/%S/g, join(home, ".local/state")).replace(/%E/g, config).replace(/%h/g, home);
const unit = name => existsSync(join(units, name)) ? spec(readFileSync(join(units, name), "utf8")) : "";
const path = unit("zed-tacit-theme.path"), service = unit("zed-tacit-theme.service");
const watched = [...path.matchAll(/^PathChanged=(.*)$/gm)].map(m => m[1]).sort();
// what the generator reads, in this home, as it says itself
const gen = existsSync(join(scripts, "zed-tacit-theme.sh")) ? readFileSync(join(scripts, "zed-tacit-theme.sh"), "utf8") : "";
const reads = ["COLORS", "CONFIG"].map(v => {
  const r = spawnSync("bash", ["-c", `${(gen.match(new RegExp(`^${v}=.*$`, "m")) ?? [""])[0]}; echo "$${v}"`], { env, encoding: "utf8" });
  return r.stdout.trim();
}).sort();
check("it watches the two files the generator reads", JSON.stringify(watched) === JSON.stringify(reads), `${JSON.stringify(watched)} vs ${JSON.stringify(reads)}`);
check("which are where the shell writes them (Directories.qml)", reads.includes(join(state, "colors.json")) && reads.includes(join(config, "illogical-impulse/config.json")));
check("and runs the generator once per change, then nothing", /^Type=oneshot$/m.test(service) && !/^Restart=/m.test(service)
  && (service.match(/^ExecStart=(.*)$/m)?.[1] ?? "") === join(scripts, "zed-tacit-theme.sh"), service);

console.log("== taking it out (contrib/zed/uninstall.sh)");
const un = run("uninstall.sh");
check("it runs to the end", un.status === 0, un.stderr);
check("the units and the generator are gone, the path unit stopped", ["zed-tacit-theme.path", "zed-tacit-theme.service"].every(u => !existsSync(join(units, u)))
  && !existsSync(join(scripts, "zed-tacit-theme.sh")) && /disable --now zed-tacit-theme\.path/.test(log()));
check("the theme stays, as it says", existsSync(theme));

console.log("== the theme it makes (contrib/zed/scripts/zed-tacit-theme.sh)");
const colors = join(state, "colors.json"), settings = join(config, "illogical-impulse/config.json");
const generate = (pal, transparency) => {
  if (pal != null) writeFileSync(colors, typeof pal === "string" ? pal : JSON.stringify(pal));
  if (transparency) writeFileSync(settings, JSON.stringify({ appearance: { transparency } }));
  return spawnSync("bash", [join(dir, "scripts/zed-tacit-theme.sh")], { cwd: sandbox, env, encoding: "utf8" });
};
const style = () => { try { return JSON.parse(readFileSync(theme, "utf8")).themes[0].style; } catch (e) { return null; } };
const alphaOf = key => (style()?.[key] ?? "").slice(7).toUpperCase();
generate(palette(1), { enable: false });
check("Solid: the editor's ground is the palette's surface, opaque", style()?.["editor.background"] === palette(1).surface_container + "FF",
  style()?.["editor.background"]);
generate(null, { enable: true, automatic: true });
check("Frosted: 15 % through, as Tacit's windows (D9)", alphaOf("editor.background") === "D9", alphaOf("editor.background"));
generate(null, { enable: true, automatic: false, backgroundTransparency: 0.4 });
check("Clear: as much as the setting lets through (0.4: 99)", alphaOf("editor.background") === "99", alphaOf("editor.background"));
generate(null, { enable: true, automatic: false, backgroundTransparency: 0.25 });
check("and follows it (0.25: BF)", alphaOf("editor.background") === "BF", alphaOf("editor.background"));

// a colour that stays the same on another palette was typed, not taken from it; fully see-through ones are no colour
generate(palette(1), { enable: false });
const one = style();
generate(palette(2));
const two = style();
const typed = [];
const walk = (a, b, at) => {
  if (typeof a === "string" && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(a)) { if (a === b && !/00$/i.test(a.slice(7) || "ff")) typed.push(`${at} ${a}`); }
  else if (a && typeof a === "object") for (const k of Object.keys(a)) walk(a[k], b?.[k], `${at}.${k}`);
};
walk(one, two, "style");
check("every colour comes from the wallpaper's palette", one && two && typed.length === 0, typed.join(", "));
const unseen = Object.entries(one?.syntax ?? {}).filter(([, v]) => /^#[0-9a-f]{6}00$/i.test(v?.color ?? "")).map(([k]) => k);
check("no kind of code is drawn in a see-through colour", one && unseen.length === 0, unseen.join(", "));

const before = readFileSync(theme, "utf8"), was = statSync(theme);
const again = generate(palette(2));
const now = statSync(theme);
check("nothing changed: Tacit.json is left as it is, so Zed has nothing to reload", again.status === 0 && now.ino === was.ino && now.mtimeMs === was.mtimeMs);
const empty = generate("");
check("colors.json caught empty while matugen rewrites it: the last theme stays, whole", empty.status !== 0 && readFileSync(theme, "utf8") === before,
  `exit ${empty.status}, Tacit.json ${statSync(theme).size} bytes`);
const half = generate(JSON.stringify(palette(3)).slice(0, 300));
check("and caught half written", half.status !== 0 && readFileSync(theme, "utf8") === before, `exit ${half.status}, Tacit.json ${statSync(theme).size} bytes`);
const leftovers = [join(config, "zed"), join(config, "zed/themes")].flatMap(d => spawnSync("ls", ["-A", d], { encoding: "utf8" }).stdout.split("\n"))
  .filter(f => f && !["themes", "scripts", "Tacit.json"].includes(f));
check("no file of its own is left beside the theme (Zed loads every file in its themes folder)", leftovers.length === 0, leftovers.join(", "));
rmSync(sandbox, { recursive: true, force: true });
done();
