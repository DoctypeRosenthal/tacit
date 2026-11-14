"""tacit-install's mirror list over a throwaway root: python3 setup_mirrors.py <tacit-install>.
Runs the installer's own mirrors() (nothing outside the throwaway root is touched) and checks that a new install updates
from Tacit's server and, when that is slow or down, from Arch's archive of the day tacit-session names, never from a
live Arch mirror (Discord, 2026-11-14: one there took Hyprland past the plugins')."""
import importlib.machinery, importlib.util, os, re, sys, tempfile
sys.dont_write_bytecode = True
src = open(sys.argv[1]).read()
if "def mirrors(" not in src:
    print("FAIL tacit-install writes Tacit's server alone: when it is slow or down an update has nowhere on the same day to go")
    sys.exit(1)
loader = importlib.machinery.SourceFileLoader("tacit_install", sys.argv[1])
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("tacit_install", loader))
loader.exec_module(m)

TACIT = "https://mirror.tacitos.co/$repo/os/$arch"
bad = 0


def check(name, ok, got=""):
    global bad
    bad += not ok
    print(f"{'ok  ' if ok else 'FAIL'} {name}" + ("" if ok or not got else f": {got!r}"))


def servers(day=None, stick=None, machine="x86_64"):
    """The servers pacman would use, in order, from the list mirrors() writes into a new root."""
    m.TARGET = tempfile.mkdtemp()
    os.makedirs(f"{m.TARGET}/etc/pacman.d")
    if stick is not None:
        open(f"{m.TARGET}/etc/pacman.d/mirrorlist", "w").write(stick)
    if day is not None:
        os.makedirs(f"{m.TARGET}/usr/share/tacit")
        open(f"{m.TARGET}/usr/share/tacit/arch-day", "w").write(day)
    real = m.os.uname
    m.os.uname = lambda: type("u", (), {"machine": machine})()
    try:
        m.mirrors()
    finally:
        m.os.uname = real
    text = open(f"{m.TARGET}/etc/pacman.d/mirrorlist").read()
    return [re.sub(r"^\s*Server\s*=\s*", "", l) for l in text.splitlines() if re.match(r"\s*Server\s*=", l)], text


got, text = servers("2026/11/09\n")
check("Tacit's server first, then Arch's archive of tacit-session's day, and no other",
      got == [TACIT, "https://archive.archlinux.org/repos/2026/11/09/$repo/os/$arch"], got)
check("every line is a server or a comment", all(l.startswith(("Server = ", "# ")) for l in text.splitlines()), text)
got, _ = servers("2026/11/09", stick="Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\nServer = https://fastly.mirror.pkgbuild.com/$repo/os/$arch\n")
check("the stick's live mirrors are not carried over", not any("pkgbuild.com" in s for s in got), got)
got, _ = servers()
check("with no day to read (a tacit-session from before it), Tacit's server alone, no archive line with an empty day", got == [TACIT], got)
got, _ = servers("not a day")
check("a day file that says no day is not used", got == [TACIT], got)
got, _ = servers("2026/11/09", machine="aarch64")
check("aarch64 keeps Arch Linux ARM's server", got == ["http://mirror.archlinuxarm.org/$arch/$repo"], got)
sys.exit(1 if bad else 0)
