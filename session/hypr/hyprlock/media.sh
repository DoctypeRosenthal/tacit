#!/usr/bin/env bash
# "Title · Artist · playing" from the active MPRIS player; empty when there is none.
# fields split on \x1f, which a title cannot hold ('|' is common in one); read -r with a non-space IFS keeps empty fields
out=$(playerctl metadata --format $'{{status}}\x1f{{title}}\x1f{{artist}}' 2>/dev/null) || exit 0
IFS=$'\x1f' read -r st title artist <<<"$out"
[[ -z $title || $st == Stopped ]] && exit 0
line=$title
[[ -n $artist ]] && line+=" · $artist"
[[ $st == Playing ]] && line+=" · playing" || line+=" · paused"
# the label's text is Pango markup: a title with & or < would blank it
line=${line//&/'&amp;'} line=${line//</'&lt;'} line=${line//>/'&gt;'}
echo "$line"
