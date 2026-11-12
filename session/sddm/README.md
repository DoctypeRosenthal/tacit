# session/sddm/

Tacit's login screen (owner's choice 2026-10-08: Tacit's own, not the Thyx theme it had): SDDM on Wayland in a weston
kiosk, the theme `tacit/` drawn with the lock screen's values (BootLockSurface.qml) so signing in looks like unlocking.

| File | Installed as |
|---|---|
| `tacit/` | `/usr/share/sddm/themes/tacit` (`theme.conf.user` links to `/var/lib/tacit-login/theme.conf`) |
| `tacit-login-ground` | `/usr/lib/tacit/tacit-login-ground`: as root before the greeter, copies the newest person's lock ground and colours into `/var/lib/tacit-login` (owned plain files only), and the keyboard layout Setup chose into `/etc/xdg/weston/weston.ini` for the greeter's weston |
| `sddm.service.d/tacit-login.conf` | `/usr/lib/systemd/system/sddm.service.d/` (runs the above when the daemon starts) |
| `tacit-login-ground.service` | `/usr/lib/systemd/system/`: runs the same copy again; the shell starts it as the person logs out, because SDDM brings the greeter back without restarting its service |
| `50-tacit-login-ground.rules` | `/usr/share/polkit-1/rules.d/`: lets the person start that service without a password |
| `tacit.conf` | `/usr/lib/sddm/sddm.conf.d/tacit.conf` (Wayland, the theme, the cursor) |

This replaces the Thyx theme, its colour template and `book4-sddm-theme-sync` with its sudo rule. Autologin stays a
per-computer choice (/etc/sddm.conf.d/autologin.conf, not packaged).
