// tacit-install's mirror list (scripts/setup/tacit-install over a throwaway root): Tacit's server, then Arch's archive of
// the same day for when it is slow or down, never a live Arch mirror (Discord, 2026-11-14: Tacit's server followed by two
// live mirrors took Hyprland 0.57.2 in, and the window line's plugin, built for 0.57.0, stopped loading)
import { spawnSync } from "child_process";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { tree } from "./lib/check.mjs";
console.log("== the mirror list of a new install (scripts/setup/tacit-install)");
const r = spawnSync("python3", ["-I", join(dirname(fileURLToPath(import.meta.url)), "lib", "setup_mirrors.py"), join(tree, "scripts/setup/tacit-install")], { encoding: "utf8" });
process.stdout.write(r.stdout + r.stderr);
process.exit(r.status ?? 1);
