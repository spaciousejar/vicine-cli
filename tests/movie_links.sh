#!/bin/sh
# Self-check for movie_best_url / movie_quality_url in vicine.
# Both are extracted from the real script at runtime.
# Usage: sh tests/movie_links.sh

SCRIPT="$(dirname "$0")/../vicine"
for fn in movie_best_url movie_quality_url; do
    eval "$(sed -n "/^${fn}() {/,/^}/p" "$SCRIPT")" || { echo "could not extract $fn" >&2; exit 1; }
done

_fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. best = highest resolution in the description, not the last line.
out="$(movie_best_url 'https://cdn/x/720p.mp4	720p	1.0GB
https://cdn/x/1080p.mp4	1080p	1.5GB
https://cdn/x/2160p.mp4	2160p	3GB')"
[ "$out" = "https://cdn/x/2160p.mp4" ] || _fail "best: expected the 2160p URL, got: $out"

# 2. quality matches the DESCRIPTION only — a later line whose URL contains
#    the quality (but whose desc is higher) must not be selected.
out2="$(movie_quality_url 'https://cdn/x/1080p.mp4	720p	1.0GB
https://cdn/x/720p.mp4	1080p	1.5GB' 720p)"
[ "$out2" = "https://cdn/x/1080p.mp4" ] || _fail "quality must match desc only (URL leak); got: $out2"

# 3. fallback: no parseable resolution -> last line.
out3="$(movie_best_url 'https://cdn/x/a.mp4	one	1.0GB
https://cdn/x/b.mp4	two	2.0GB')"
[ "$out3" = "https://cdn/x/b.mp4" ] || _fail "fallback should be the last line, got: $out3"

echo "PASS (3 checks)"