#!/bin/sh
# Self-check for install.sh's target argument. A typo used to become the
# install directory: `./install.sh --foo` ran `mkdir -p --foo` in the current
# directory and installed nothing.
# Usage: sh tests/install_args.sh

. "$(dirname "$0")/lib.sh"

SRC="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
[ -f "$SRC" ] || { echo "install.sh missing" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-install.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# run from an empty cwd: anything the script creates there is visible
run() {
    ( cd "$tmp" && sh "$SRC" "$@" ) >"$tmp/out" 2>&1
    echo "$?"
}

rc="$(run --foo)"
[ "$rc" = 2 ] || _fail "unknown flag exited $rc, want 2: $(cat "$tmp/out")"
grep -q 'usage:' "$tmp/out" || _fail "unknown flag printed no usage: $(cat "$tmp/out")"
[ -e "$tmp/--foo" ] && _fail "unknown flag created a '--foo' directory"

rc="$(run relative/dir)"
[ "$rc" = 2 ] || _fail "relative path exited $rc, want 2: $(cat "$tmp/out")"
grep -q 'usage:' "$tmp/out" || _fail "relative path printed no usage: $(cat "$tmp/out")"
[ -e "$tmp/relative" ] && _fail "relative path created a directory"

echo "PASS (5 checks)"
