#!/bin/sh
# Builds the notch's sand (Tacit.Sand) and installs it to ~/.local/lib/qml/Tacit/Sand, where QML_IMPORT_PATH
# finds it (set by the session, session/hypr/hyprland/env.lua, and by the launchers qs-supervise and tacit-app).
# Rebuild after a Qt update: the plugin is built against this Qt's exact version.
set -e
HERE=$(dirname "$(readlink -f "$0")")
B=${XDG_CACHE_HOME:-$HOME/.cache}/tacit-sand-build
python3 "$HERE/gen_shaders.py" "$B/shaders"
cmake -S "$HERE" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$B"
D=$HOME/.local/lib/qml/Tacit/Sand
mkdir -p "$D"
# by rename: a running shell has the old library mapped, and overwriting it in place can crash it
for f in libtacitsand.so qmldir tacitsand.qmltypes; do
    cp "$B/qml/Tacit/Sand/$f" "$D/.$f.new" && mv -f "$D/.$f.new" "$D/$f"
done
echo "installed $D (a running shell keeps the old one until it restarts)"
