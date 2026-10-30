#!/bin/sh
# Self-check: vicine must not depend on tools that only exist in
# util-linux/GNU coreutils — stock macOS ships none of them, and CI only
# runs Linux, so a regression there surfaces on a user's Mac. It did:
# `rev` in the parse chains left every anime quality and link size
# description empty on macOS (no coreutils in the installer's dep list).
# Usage: sh tests/portability.sh

. "$(dirname "$0")/lib.sh"

SRC="$(dirname "$0")/../vicine"

# util-linux/GNU-only commands, matched in command position only (start of a
# command, after a pipe/;/&/(), or inside $( )) so prose in comments
# ("the number column", "longer timeout") doesn't trip the check
_gnu='rev|tac|numfmt|shuf|column|seq|sha256sum|md5sum|timeout'
_gnu_re="(^|[|;&(]|\$\()[[:space:]]*($_gnu)([[:space:]]|\$)"
if grep -nE "$_gnu_re" "$SRC" >/dev/null 2>&1; then
    grep -nE "$_gnu_re" "$SRC" >&2
    _fail "util-linux/GNU-only command in $SRC — breaks macOS/BSD"
fi

# GNU-only flags and bashisms (the script promises /bin/sh)
_gnu_flags='grep -[a-zA-Z]*P|sed -i([^[:alnum:]'\''"]|$)|date -[dI]|gensub|strtonum|asort|\[\[[:space:]]'
if grep -nE "$_gnu_flags" "$SRC" >/dev/null 2>&1; then
    grep -nE "$_gnu_flags" "$SRC" >&2
    _fail "GNU-only flag or bashism in $SRC — breaks macOS/BSD or dash"
fi

# the parse chains must yield the same values on every platform: these are
# exactly the strings macOS used to get empty
load_vicine

_season='Episode 1 : https://cdn/a.m3u8,360p,480p : https://cdn/b.m3u8,480p,720p'

_q="$(qualities_of "$_season")"
[ "$_q" = "$(printf '480p\n720p')" ] || _fail "qualities_of returned: $_q"

_e="$(parse_episodes "$_season")"
[ "$_e" = "$(printf '1\thttps://cdn/b.m3u8\t720p\t480p')" ] ||
    _fail "parse_episodes returned: $_e"

_l="$(parse_links 'https://cdn/x.m3u8, Some Movie, 1.2GB')"
[ "$_l" = "$(printf 'https://cdn/x.m3u8\tSome Movie\t1.2GB')" ] ||
    _fail "parse_links returned: $_l"

echo "PASS (5 checks)"
