#!/bin/sh
# Self-check for update_history() — the one file vicine writes that survives
# between runs. It had no coverage at all.
# Usage: sh tests/history.sh

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"
load_vicine

# mac/BSD wc pads its output with spaces; GNU does not. tr both to be portable.
_wc() { wc -l < "$1" | tr -d ' '; }
need update_history

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-hist.XXXXXX")"
histfile="$tmp/history"
: > "$histfile"

# a row is written, fields in the documented order
update_history "slug-one" "The Show" series 2 7
[ "$(_wc "$histfile")" = "1" ] || _fail "first update wrote no row"
[ "$(cut -f1 "$histfile")" = "slug-one" ] || _fail "slug column"
[ "$(cut -f4 "$histfile")" = "2" ] || _fail "season column"

# re-watching the same title replaces its row instead of appending a second
update_history "slug-one" "The Show" series 3 8
[ "$(_wc "$histfile")" = "1" ] || _fail "re-watch duplicated the row"
[ "$(cut -f5 "$histfile")" = "8" ] || _fail "re-watch did not update the episode"

# numeric-looking slugs are distinct: awk's numeric compare made 005 delete 5
update_history "005" "Five" movie 0 0
update_history "5" "Five" movie 0 0
[ "$(_wc "$histfile")" = "3" ] || _fail "slug 005 and slug 5 collided"

# a title carrying a tab or newline must not forge a second row (its season
# field is interpolated into a jq program on read-back)
update_history "slug-two" "$(printf 'Evil\nTitle\tHere')" movie 0 0
[ "$(_wc "$histfile")" = "4" ] || _fail "an embedded newline/tab forged a row"

# the slug is pasted back into an API path on resume: strip anything a URL path
# cannot hold (vicine-audit V-07)
update_history "../../etc/passwd?x" "Traversal" movie 0 0
[ "$(cut -f1 "$histfile" | tail -1)" = "etcpasswdx" ] \
    || _fail "slug not sanitised: $(cut -f1 "$histfile" | tail -1)"

# an empty slug is a no-op (nothing to key the row on)
update_history "" "No slug" movie 0 0
[ "$(_wc "$histfile")" = "5" ] || _fail "an empty slug wrote a row"

# the staging file must be unique per call: a fixed "$histfile.tmp" meant two
# copies running at once truncated each other's row before the mv
grep -qF 'mktemp "$histfile.tmp.XXXXXX"' "$SCRIPT" \
    || _fail "update_history stages through a fixed temp name again"

# 8 writers at once: the read-modify-write is locked, so every row survives
# (measured before the lock: 8 writers left 1 to 2 rows)
_before="$(_wc "$histfile")"
_i=1
while [ "$_i" -le 8 ]; do
    ( update_history "conc-$_i" "C$_i" movie 0 0 ) &
    _i=$(( _i + 1 ))
done
wait
[ "$(_wc "$histfile")" = "$(( _before + 8 ))" ] \
    || _fail "concurrent writers lost rows: $(_wc "$histfile") of $(( _before + 8 ))"

# a lock left behind by a killed process must not block every later write
mkdir -p "$histfile.lock"
printf '%s\n' 999999 > "$histfile.lock/pid"
update_history "after-stale" "Stale" movie 0 0
[ "$(cut -f1 "$histfile" | tail -1)" = "after-stale" ] \
    || _fail "a stale lock blocked update_history"
[ -d "$histfile.lock" ] && _fail "update_history left its lock behind"

rm -rf "$tmp"
echo "PASS (11 checks)"
