#!/bin/sh
# Self-check for anime_variants() — the m3u8 variant parser in vicine.
# Usage: sh tests/m3u8_variants.sh
#
# The function is extracted from the real script at runtime (it's pure:
# sed/grep/sort/printf only, no script globals), so the test can never
# silently test a stale copy.

SCRIPT="$(dirname "$0")/../vicine"
eval "$(sed -n '/^anime_variants() {/,/^}/p' "$SCRIPT")"

_fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. A RESOLUTION line labels its variant; a RESOLUTION-less variant must
#    NOT inherit the previous variant's resolution and falls back to its
#    path prefix.
out="$(printf '%s\n' \
'#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=1280x720
720/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000
1080/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=500,RESOLUTION=1920x1080
1080/index.m3u8' | anime_variants dir)"

printf '%s\n' "$out" | grep -q '^720p>dir/720/index' || _fail '720 variant mislabelled'
[ "$(printf '%s\n' "$out" | grep -c '^1080p>')" = 2 ] || _fail 'want two 1080 lines: one from RESOLUTION, one from prefix fallback'
[ "$(printf '%s\n' "$out" | grep -c '^720p>')" = 1 ] || _fail 'RESOLUTION-less 1080 inherited the previous 720 label'

# 2. Best first (sort -rn puts resolution order as numeric sort).
[ "$(printf '%s\n' "$out" | head -1 | cut -d'>' -f1)" = "1080p" ] || _fail 'best variant not sorted first'

# 3. Absolute variant URLs pass through untouched.
out2="$(printf '%s\n' \
'#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=1280x720
https://cdn.example/video/720/index.m3u8' | anime_variants dir)"
printf '%s\n' "$out2" | grep -q '^720p>https://cdn.example/video/720/index' || _fail 'absolute URL not preserved'

# 4. EXT-X-I-FRAME lines (with an unquoted URI ending in index.m3u8) must
#    NOT be emitted as variants — regression guard.
out3="$(printf '%s\n' \
'#EXT-X-STREAM-INF:BANDWIDTH=500,RESOLUTION=1280x720
720/index.m3u8
#EXT-X-I-FRAME-STREAM-INF:RESOLUTION=1920x1080,URI=1080/index.m3u8' | anime_variants dir)"
[ "$(printf '%s\n' "$out3" | grep -c 'EXT-X-I-FRAME')" = 0 ] || _fail 'EXT-X-I-FRAME line leaked in as a variant'

echo "PASS (4 checks)"