#!/bin/sh
set -eu

preview_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir="$preview_dir/build-local"
qt_prefix=${QT_ROOT:-}
if [ -z "$qt_prefix" ] && command -v qtpaths >/dev/null 2>&1; then
    qt_prefix=$(qtpaths --query QT_INSTALL_PREFIX)
fi
if [ -n "$qt_prefix" ]; then
    cmake -S "$preview_dir" -B "$build_dir" "-DCMAKE_PREFIX_PATH=$qt_prefix"
else
    cmake -S "$preview_dir" -B "$build_dir"
fi
cmake --build "$build_dir" --parallel
exec "$build_dir/TacitMailMacPreview.app/Contents/MacOS/TacitMailMacPreview" "$@"
