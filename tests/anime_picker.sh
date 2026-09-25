#!/bin/sh
# Self-check for the anime episode-picker row->episode mapping (issue #5):
# the display list is "<row> <ep>"; picking display line 3 must yield
# episode 14, not a row number, for non-contiguous hianime numbering
# (0 specials, season 2 starting at 13, gaps). The mapping is the
# sed -n "row"p  lookup used by both the initial picker and the in-loop
# "select" case.
# Usage: sh tests/anime_picker.sh

_fail() { echo "FAIL: $1" >&2; exit 1; }

pick() { # $1 = display pick line ("3  14"), list on stdin
    printf '%s\n' "$LIST" | sed -n "$(printf '%s' "$1" | awk '{print $1+0}')p"
}

LIST='0
13
14
15
21'

[ "$(pick '1  0')"  = "0"  ] || _fail "row 1 -> ep 0"
[ "$(pick '2  13')" = "13" ] || _fail "row 2 -> ep 13"
[ "$(pick '3  14')" = "14" ] || _fail "row 3 -> ep 14 (got: $(pick '3  14'))"
[ "$(pick '5  21')" = "21" ] || _fail "row 5 -> ep 21"

# the old behaviour (grep -oE '[0-9]+' | head -1) would return 3 for
# "3  14" — assert it does not
[ "$(pick '3  14')" != "3" ] || _fail "row number leaked instead of episode number"

echo "PASS (5 checks)"