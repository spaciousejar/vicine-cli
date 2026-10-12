#!/bin/sh
# Self-check for eps_by_request() in vicine — the -e N / N-M / -1 narrowing
# shared by the series and anime -D flows (and their confirm counts).
# Usage: sh tests/eps_by_request.sh
#
# The suite sources the real script (VICINE_LIB=1 vicine).

VICINE_LIB=1 . "$(dirname "$0")/../vicine"
command -v eps_by_request >/dev/null 2>&1 || { echo "eps_by_request missing" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

LINES='1	https://a/1.mp4	480p
2	https://a/2.mp4	720p
3	https://a/3.mp4	1080p
4	https://a/4.mp4	1080p
5	https://a/5.mp4	1080p'

got() { # $1 = -e value -> the episode numbers the filter kept
    eps_by_request "$LINES" "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'
}

[ "$(got 3)" = "3" ]              || _fail "-e 3 -> got: $(got 3)"
[ "$(got 2-4)" = "2 3 4" ]        || _fail "-e 2-4 -> got: $(got 2-4)"
# 4--1 means "episode 4 to the last", so 4 is INCLUDED. This used to expect
# "5": the start bound was parsed as "4-" and awk compared it as a string.
[ "$(got 4--1)" = "4 5" ]         || _fail "-e 4--1 (end=-1 => last) -> got: $(got 4--1)"
[ "$(got -1)" = "5" ]             || _fail "-e -1 (latest) -> got: $(got -1)"
[ "$(got '')" = "1 2 3 4 5" ]     || _fail "-e '' (all) -> got: $(got '')"
[ "$(got 99)" = "" ]              || _fail "-e 99 (out of range) -> got: $(got 99)"

echo "PASS (6 checks)"