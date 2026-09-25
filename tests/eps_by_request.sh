#!/bin/sh
# Self-check for eps_by_request() in vicine — the -e N / N-M / -1 narrowing
# shared by the series and anime -D flows (and their confirm counts).
# Usage: sh tests/eps_by_request.sh
#
# The function is extracted from the real script at runtime.

SCRIPT="$(dirname "$0")/../vicine"
eval "$(sed -n '/^eps_by_request() {/,/^}/p' "$SCRIPT")" || { echo "could not extract eps_by_request" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

LINES='1	https://a/1.mp4	480p
2	https://a/2.mp4	720p
3	https://a/3.mp4	1080p
4	https://a/4.mp4	1080p
5	https://a/5.mp4	1080p'

got() { # $1 = -e value
    printf '%s\n' "$LINES" | eps_by_request - "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'
}

# extraction above already required the function; use it with the real shape
got2() {
    eps_by_request "$LINES" "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'
}

[ "$(got2 3)" = "3" ]              || _fail "-e 3 -> got: $(got2 3)"
[ "$(got2 2-4)" = "2 3 4" ]        || _fail "-e 2-4 -> got: $(got2 2-4)"
[ "$(got2 4--1)" = "5" ]           || _fail "-e 4--1 (end=-1 => last) -> got: $(got2 4--1)"
[ "$(got2 -1)" = "5" ]             || _fail "-e -1 (latest) -> got: $(got2 -1)"
[ "$(got2 '')" = "1 2 3 4 5" ]     || _fail "-e '' (all) -> got: $(got2 '')"
[ "$(got2 99)" = "" ]              || _fail "-e 99 (out of range) -> got: $(got2 99)"

echo "PASS (6 checks)"