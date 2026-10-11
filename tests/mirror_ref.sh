#!/bin/sh
# Self-check for mirror_ref() in vicine — the Referer origin handed to the
# mirror gateways (nexdrive/fastdl).
#
# The regression: it was built inline as "https://${1%%/*}/", which cuts at the
# FIRST slash ("https:/" -> "https:"), so every gateway call carried the bogus
# header "Referer: https://https:/" and could be blocked as a hotlink.
# Usage: sh tests/mirror_ref.sh
#
# Also guards mirror_search's scratch dir against reverting to a predictable
# /tmp/VICINE.vega.$$ name (see the mktemp -d checks at the end).

VICINE_LIB=1 . "$(dirname "$0")/../vicine"
command -v mirror_ref >/dev/null 2>&1 || { echo "mirror_ref missing from vicine" >&2; exit 1; }
SCRIPT="$(dirname "$0")/../vicine"

_fail() { echo "FAIL: $1" >&2; exit 1; }

_check() { # $1 url, $2 expected origin
    _got="$(mirror_ref "$1")"
    [ "$_got" = "$2" ] || _fail "mirror_ref '$1' -> '$_got', want '$2'"
}

_check "https://vegamovies.gallery/download-movie-slug/" "https://vegamovies.gallery/"
_check "https://rogmovies.best/some-title/" "https://rogmovies.best/"
_check "https://vegamovies.gallery/some-title" "https://vegamovies.gallery/"

# the broken expansion must not come back
[ "$(mirror_ref "https://vegamovies.gallery/x/")" != "https://https:/" ] \
    || _fail "mirror_ref still produces the broken https://https:/ referer"

# mirror_search stages into a private dir, not a predictable /tmp/VICINE.vega.$$:
# a lower-trust local user could pre-create that name (or a symlink) and receive
# the victim's fetches. mktemp -d closes the guessable path.
grep -qF 'VICINE.vega.$$' "$SCRIPT" && _fail "mirror_search reverted to a predictable temp dir name"
grep -qF 'mktemp -d' "$SCRIPT" || _fail "mirror_search does not create its temp dir with mktemp -d"

echo "PASS (6 checks)"
