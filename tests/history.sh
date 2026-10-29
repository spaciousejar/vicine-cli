#!/bin/sh
# Self-check for update_history() — the one file vicine writes that survives
# between runs. It had no coverage at all.
# Usage: sh tests/history.sh

SCRIPT="$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
VICINE_LIB=1 . "$SCRIPT"

_fail() { echo "FAIL: $1" >&2; exit 1; }
# mac/BSD wc pads its output with spaces; GNU does not. tr both to be portable.
_wc() { wc -l < "$1" | tr -d ' '; }
command -v update_history >/dev/null 2>&1 || { echo "update_history missing from vicine" >&2; exit 1; }

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

rm -rf "$tmp"
echo "PASS (9 checks)"