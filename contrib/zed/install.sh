#!/usr/bin/env bash
# Install the Tacit theme for Zed (contrib/zed/install.sh): copies the generator, makes the theme from the wallpaper's
# colours, and sets a systemd path unit that makes it again whenever the colours or the see-through setting change.
# Then pick Tacit in Zed's theme selector. contrib/zed/uninstall.sh takes it out again.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ZED_DIR="$CONFIG/zed"
ZED_SCRIPTS="$ZED_DIR/scripts"
ZED_THEMES="$ZED_DIR/themes"
SYSTEMD_USER="$CONFIG/systemd/user"

echo "==> Zed Tacit Theme Installer"
echo

# Ensure directories exist
mkdir -p "$ZED_SCRIPTS" "$ZED_THEMES" "$SYSTEMD_USER"

# An earlier version looked at the files every 5 s from a service of its own; the path unit below replaces it
if [[ -f "$SYSTEMD_USER/zed-tacit-theme-watch.service" ]]; then
    systemctl --user disable --now zed-tacit-theme-watch.service 2>/dev/null || true
    rm -f "$SYSTEMD_USER/zed-tacit-theme-watch.service" "$ZED_SCRIPTS/zed-tacit-watch.sh"
    echo "   Removed the old watcher"
fi

# Copy the generator
cp "$SCRIPT_DIR/scripts/zed-tacit-theme.sh" "$ZED_SCRIPTS/"
chmod +x "$ZED_SCRIPTS/zed-tacit-theme.sh"
echo "   Installed the generator to $ZED_SCRIPTS"

# Copy the systemd units
cp "$SCRIPT_DIR/systemd/zed-tacit-theme.path" "$SCRIPT_DIR/systemd/zed-tacit-theme.service" "$SYSTEMD_USER/"
echo "   Installed the units to $SYSTEMD_USER"

# Generate initial theme
"$ZED_SCRIPTS/zed-tacit-theme.sh"
echo "   Generated $ZED_THEMES/Tacit.json"

# Make it again on every change
systemctl --user daemon-reload
systemctl --user enable --now zed-tacit-theme.path
echo "   Started zed-tacit-theme.path"

echo
echo "==> Install complete."
echo "   In Zed, pick Tacit in the theme selector (Ctrl+K Ctrl+T)."
echo "   The theme follows the wallpaper and the see-through setting from now on."
