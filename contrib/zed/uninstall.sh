#!/usr/bin/env bash
# Remove Zed Tacit theme integration.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ZED_SCRIPTS="$CONFIG/zed/scripts"
SYSTEMD_USER="$CONFIG/systemd/user"

echo "==> Zed Tacit Theme Uninstaller"
echo

# the path unit, and the watcher service of an earlier version
systemctl --user disable --now zed-tacit-theme.path zed-tacit-theme-watch.service 2>/dev/null || true
echo "   Stopped watching"

rm -f "$ZED_SCRIPTS/zed-tacit-theme.sh" "$ZED_SCRIPTS/zed-tacit-watch.sh"
echo "   Removed scripts"

rm -f "$SYSTEMD_USER/zed-tacit-theme.path" "$SYSTEMD_USER/zed-tacit-theme.service" "$SYSTEMD_USER/zed-tacit-theme-watch.service"
systemctl --user daemon-reload
echo "   Removed the units"

echo
echo "==> Uninstall complete."
echo "   Your existing Tacit.json theme remains in $CONFIG/zed/themes/"
