#!/usr/bin/env bash
# Path of the current album art for hyprlock's image reload; a transparent pixel when none.
# the transparent pixel is packaged next to this script; fetched art is kept in the cache folder, a day at most
blank=$(dirname "$(readlink -f "$0")")/cache/blank.png
cache=${XDG_CACHE_HOME:-$HOME/.cache}/tacit/lock-art
mkdir -p "$cache"
find "$cache" -type f -mtime +0 -delete 2>/dev/null
url=$(playerctl metadata mpris:artUrl 2>/dev/null)
st=$(playerctl status 2>/dev/null)
if [[ -z $url || $st == Stopped ]]; then echo "$blank"; exit; fi
case $url in
  file://*) p=${url#file://}
            # percent-decoded: %20 and the bytes of accented letters (backslashes doubled so %b leaves them)
            p=${p//\\/\\\\}
            printf '%b\n' "${p//%/\\x}";;
  http*) f=$cache/art-$(echo -n "$url" | md5sum | cut -c1-12).png
         [[ -s $f ]] || { curl -fsL --max-time 3 "$url" -o "$f.part" 2>/dev/null && mv -f "$f.part" "$f"; }
         [[ -s $f ]] && echo "$f" || echo "$blank";;
  *) echo "$blank";;
esac
