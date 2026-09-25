#!/bin/sh
# Self-check for command-line validation in vicine: value-taking flags must
# reject a missing operand, and -n must be a non-negative integer. Both die
# during argument parsing, before any network access.
# Usage: sh tests/args.sh   (override the target with VICINE="bash ../vicine")
# so the shell matrix can exercise the real script under bash/dash.

VICINE="${VICINE:-"$(dirname "$0")/../vicine"}"

_fail() { echo "FAIL: $1" >&2; exit 1; }

# runs a broken invocation; returns via _out/_rc
check() { # $1 = args, $2 = expected message fragment
    _out="$($VICINE $1 2>&1)"; _rc=$?
    [ "$_rc" -ne 0 ] || _fail "'vicine $1' should exit non-zero"
    printf '%s\n' "$_out" | grep -qF -e "$2" || _fail "'vicine $1' should say \"$2\", got: $_out"
}

check "-q"            "Missing value for -q/--quality"
check "-p"            "Missing value for -p/--player"
check "-e"            "Missing value for -e/--episode"
check "-n"            "Missing value for -n/--select-nth"
check "--download-dir" "Missing value for --download-dir"
check "-n abc"        "--select-nth must be a non-negative integer"

# a genuinely valid parse must NOT trip any of these (helps catch a
# validation that fires on normal use)
$VICINE -h >/dev/null 2>&1 || _fail "'vicine -h' should exit 0"

echo "PASS (7 checks)"