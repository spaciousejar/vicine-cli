#!/bin/sh
# Self-check for movie_playable in vicine — the walk-the-candidates movie picker.
# Usage: sh tests/movie_links.sh

# source the real script (VICINE_LIB) rather than sed-ing functions out of it
VICINE_LIB=1 . "$(dirname "$0")/../vicine"
command -v movie_playable >/dev/null 2>&1 || { echo "movie_playable missing from vicine" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }
# quiet the walker's stderr (it warns per dead candidate)
warn() { :; }

# 4. movie_playable: walks candidates (requested quality first, then best->
#    worst resolution) and returns the FIRST one that serves media. Network
#    stubbed: resolve_stream_url passes through, curl returns a body per URL
#    (404 pages, source HTML pages, JSON, empty, and a real MKV header).
# shellcheck disable=SC2034  # quality is read by the sourced movie_playable
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

# shellcheck disable=SC2034  # quality is read by the sourced movie_playable
# 4b. requested quality wins its tier when ITS body is media
quality=720p
out="$(movie_playable "$TEAM")"
[ "$out" = "https://b/480.mkv" ] || _fail "720p page must fall through; got: $out"

TEAM2='https://b/1080b.mkv	1080p	2GB
https://b/720p.mkv	720p	1GB'
# 4c. quality tier: ask 720p, 720p row is real -> picked (not the 1080 row)
# shellcheck disable=SC2034  # quality is read by the sourced movie_playable
quality=720p
out="$(movie_playable "$TEAM2")"
[ "$out" = "https://b/720p.mkv" ] || _fail "quality first: got: $out"

# 4d. nothing alive -> empty output
TEAM3='https://b/x.mp4	nope	1MB'
out="$(movie_playable "$TEAM3")"
[ -z "$out" ] || _fail "all-dead must return empty; got: $out"

echo "PASS (4 checks)"