#!/bin/sh
# shellcheck disable=SC2034  # quality/curl_exe are read by the sourced movie_playable
# Self-check for movie_playable in vicine — the walk-the-candidates movie picker.
# Usage: sh tests/movie_links.sh

# source the real script (VICINE_LIB) rather than sed-ing functions out of it
. "$(dirname "$0")/lib.sh"

load_vicine
need movie_playable

# quiet the walker's stderr (it warns per dead candidate)
warn() { :; }
# movie_playable calls "$curl_exe" so the stub below has to be reachable
curl_exe=curl

# 4. movie_playable: walks candidates (requested quality first, then best->
#    worst resolution) and returns the FIRST one that serves media. Network
#    stubbed: resolve_stream_url passes through, curl returns a body per URL
#    (404 pages, source HTML pages, JSON, empty, and a real MKV header).
quality=best
TEAM='https://b/1080.mkv	1080p Bluray	2GB
https://b/720.mkv	720p Bluray	1GB
https://b/480.mkv	480p	400MB'
resolve_stream_url() { printf '%s' "$1"; }
curl() {
    case "$*" in
        *1080.mkv*) printf '<!doctype html>404 not found' ;;
        *720.mkv*)  printf '\n<!DOCTYPE html><head>' ;;   # source page at 200
        *720p.mkv*) printf '%b' '\032E\337\243B\206\201\001' ;;
        *480.mkv*)  printf '%b' '\032E\337\243B\206\201\001' ;;
        *)          printf '' ;;
    esac
}
out="$(movie_playable "$TEAM")"
[ "$out" = "https://b/480.mkv" ] || _fail "dead best must fall through to live 480p; got: $out"

# 4b. requested quality wins its tier when ITS body is media
quality=720p
out="$(movie_playable "$TEAM")"
[ "$out" = "https://b/480.mkv" ] || _fail "720p page must fall through; got: $out"

TEAM2='https://b/1080b.mkv	1080p	2GB
https://b/720p.mkv	720p	1GB'
# 4c. quality tier: ask 720p, 720p row is real -> picked (not the 1080 row)
quality=720p
out="$(movie_playable "$TEAM2")"
[ "$out" = "https://b/720p.mkv" ] || _fail "quality first: got: $out"

# 4d. nothing alive -> empty output
TEAM3='https://b/x.mp4	nope	1MB'
out="$(movie_playable "$TEAM3")"
[ -z "$out" ] || _fail "all-dead must return empty; got: $out"

# 4e. at most 3 candidates are probed: the 4th (lowest resolution) is live
#     here, so a run that returns it means the cap stopped working
curl() {
    case "$*" in
        *360.mkv*) printf '%b' '\032E\337\243B\206\201\001' ;;
        *)         printf '<!doctype html>404 not found' ;;
    esac
}
TEAM4='https://b/1080c.mkv	1080p	2GB
https://b/720c.mkv	720p	1GB
https://b/480c.mkv	480p	400MB
https://b/360c.mkv	360p	200MB'
out="$(movie_playable "$TEAM4")"
[ -z "$out" ] || _fail "4th candidate must not be probed; got: $out"

echo "PASS (5 checks)"
