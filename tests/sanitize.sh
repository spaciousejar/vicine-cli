#!/bin/sh
# Self-check for sanitize() — on every download path and the control for the
# #43 path-escape fix. Had zero coverage before issue #53.
# Usage: sh tests/sanitize.sh

. "$(dirname "$0")/lib.sh"

load_vicine

need sanitize

[ "$(sanitize 'a/b')" = "ab" ] \
    || _fail "slash not stripped: $(sanitize 'a/b')"
# '.' must survive: the file gets a .mp4 suffix, so a pure-dot title cannot
# traverse, and the caller sanitises the whole path it mkdir -p's (#43).
[ "$(sanitize '..')" = ".." ] \
    || _fail "dots must survive, got: $(sanitize '..')"
[ "$(sanitize 'a b')" = "a_b" ] \
    || _fail "space not underscored: $(sanitize 'a b')"
[ "$(sanitize 'x*y?z"q<r>s|t')" = "xyzqrst" ] \
    || _fail "hostile chars not stripped: $(sanitize 'x*y?z"q<r>s|t')"
[ "$(sanitize 'हिन्दी दुबई')" = "हिन्दी_दुबई" ] \
    || _fail "non-Latin script lost: $(sanitize 'हिन्दी दुबई')"
[ "$(sanitize '.')" = "." ] \
    || _fail "'.' emptied"
# an all-hostile title must still yield a stable, non-empty name
case "$(sanitize '///')" in
    vicine_[0-9]*) ;;
    *) _fail "degenerate title needs the numeric fallback: $(sanitize '///')" ;;
esac

echo "PASS (7 checks)"
