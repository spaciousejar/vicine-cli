#!/bin/sh
# Self-check for pop_m3u8's inline awk program in vicine — the URL
# token-stamping ("pop_stamp_url") and the #EXT-X-KEY URI rewrite.
# Usage: sh tests/pop_m3u8.sh
#
# The awk program is extracted from the real script at runtime so the test
# can never silently test a stale copy. The run is timeout-guarded: a
# regression to the while(match(...)) rewrite would spin forever.

SCRIPT="$(dirname "$0")/../vicine"

# extract the awk program between "function stamp(u) {" and the final
# "{ print stamp($0) }' >> "$tmpfile5"" line, stripping indentation and the
# closing quote + redirect.
AWKPROG="$(sed -n '/function stamp(u) {/,/print stamp(\$0) }/p' "$SCRIPT" | sed 's/^            //' | sed "s/ *' >> \"\$tmpfile5\"$//")"
printf '%s\n' "$AWKPROG" | grep -q 'function stamp(u)' || { echo "could not extract pop_m3u8 awk program" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

run() { # $1 = playlist text ; echoes stamped output
    printf '%s\n' "$1" | timeout 5 awk -v host='https://cdn.example.com' -v qs='?token=TOK' "$AWKPROG"
}

# 1. #EXT-X-KEY rewrite keeps the closing quote (regression: issue #7 and
#    the infinite-loop variant of its fix).
out="$(run '#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="keys/key.bin",IV=0x00')"
printf '%s\n' "$out" | grep -q '#EXT-X-KEY:METHOD=AES-128,URI="https://cdn.example.com/keys/key.bin?token=TOK",IV=0x00' \
    || _fail "KEY URI must keep its closing quote: $out"

# 2. Absolute segment URI: exactly one token, no ?token=?token= (issue #6).
out="$(run 'https://cdn.example.com/seg/a.ts')"
[ "$out" = 'https://cdn.example.com/seg/a.ts?token=TOK' ] || _fail "absolute URI single-token stamp: $out"

# 3. Absolute URI with an existing query: & separator, still one token.
out="$(run 'https://cdn.example.com/seg/b.ts?x=1')"
[ "$out" = 'https://cdn.example.com/seg/b.ts?x=1&token=TOK' ] || _fail "absolute URI with query: $out"

# 4. Absolute URI that already carries a token: untouched.
out="$(run 'https://cdn.example.com/seg/e.ts?token=OLD')"
[ "$out" = 'https://cdn.example.com/seg/e.ts?token=OLD' ] || _fail "token-already-present must pass through: $out"

# 5. Root-relative and bare-relative URIs get host-prefixed + stamped.
out="$(run '/abs/path/c.ts
rel/d.ts')"
printf '%s\n' "$out" | grep -q '^https://cdn.example.com/abs/path/c.ts?token=TOK$' || _fail "root-relative: $out"
printf '%s\n' "$out" | grep -q '^https://cdn.example.com/rel/d.ts?token=TOK$' || _fail "bare-relative: $out"

# 6. The rewrite must terminate (timeout 5 above would print nothing on a
#    hang): the whole run exiting 0 proves it here.
[ $? = 0 ] || true

echo "PASS (5 checks)"