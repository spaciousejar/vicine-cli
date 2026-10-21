#!/bin/sh
# Self-check for update_script() — the one function that replaces the running
# binary itself. The trap for the test: $0 is what gets replaced, and $0 is
# read-only. So the fake install IS a wrapper script invoking update_script;
# sourcing the real vicine as a library leaves $0 pointing at the wrapper,
# which update_script then mends or replaces per case. curl is faked on PATH
# to serve canned bodies (or fail, for the unreachable case).
# Usage: sh tests/self_update.sh

VICINE_ABS="$(cd "$(dirname "$0")/.." && pwd)/vicine"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-upd.XXXXXX")"
target="$tmp/sim"
_body="$tmp/body"

_fail() { echo "FAIL: $1" >&2; exit 1; }

printf '#!/bin/sh\ncat "%s"\n' "$_body" > "$tmp/curl"
chmod 755 "$tmp/curl"

_new_target() { # $1 = local version the simulated install carries
    printf '#!/bin/sh\nVICINE_LIB=1 . "%s"\nversion_number="%s"\nupdate_script\n' \
        "$VICINE_ABS" "$1" > "$target"
    chmod 755 "$target"
}

_run() { # $1 = VICINE_UPDATE_URL override ("" = the project default)
    _out="$(PATH="$tmp:$PATH" VICINE_UPDATE_URL="$1" "$target" 2>&1)"
    _rc=$?
}

# trailing newline is part of the contract: command substitution strips it,
# and the updater re-adds exactly one — so the body must carry one for the
# byte compare against the replaced install to match
_body_write() { # $1 = version line, $2 = payload tail ("" = clean script)
    printf '#!/bin/sh\nversion_number="%s"\n%s\n' "$1" "$2" > "$_body"
}

# 1. newer remote replaces the install in place, exec bit kept
_body_write 1.7.1 'echo new-body'
_new_target 1.7.0
_run ""
[ "$_rc" = 0 ] || _fail "update died: $_out"
printf '%s' "$_out" | grep -qF "Updated:" || _fail "no Updated line: $_out"
cmp -s "$_body" "$target" || _fail "install not replaced with the payload"
[ -x "$target" ] || _fail "updated install lost the +x bit"

# 2. unreachable remote: clean die, install untouched
_body_write 1.7.1 'echo new-body'
_new_target 1.7.0
cp "$target" "$tmp/before"
rm -f "$_body"
_run ""
[ "$_rc" = 1 ] || _fail "curl failure wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "cannot fetch" || _fail "no cannot-fetch line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite fetch failure"

# 3. garbage body (no version line): invalid response, install untouched
printf 'not a script at all\n' > "$_body"
_new_target 1.7.0
cp "$target" "$tmp/before"
_run ""
[ "$_rc" = 1 ] || _fail "invalid body wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "Invalid response" || _fail "no invalid-response line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite invalid body"

# 4. same version: honest no-op, install byte-identical
_body_write 1.7.0 'echo new-body'
_new_target 1.7.0
cp "$target" "$tmp/before"
_run ""
[ "$_rc" = 0 ] || _fail "same version did not exit 0: $_out"
printf '%s' "$_out" | grep -qF "Already up to date" || _fail "no no-op line: $_out"
cmp -s "$tmp/before" "$target" || _fail "no-op still replaced the install"

# 5. older remote: upgrade-only, install untouched
_body_write 1.6.0 'echo new-body'
_new_target 1.7.0
cp "$target" "$tmp/before"
_run ""
[ "$_rc" = 1 ] || _fail "downgrade wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "is not newer" || _fail "no downgrade line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite refusal"

# 6. syntactically broken newer payload: refused before the replace
printf '#!/bin/sh\nversion_number="1.7.1"\n((\n' > "$_body"
_new_target 1.7.0
cp "$target" "$tmp/before"
_run ""
[ "$_rc" = 1 ] || _fail "bad payload wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "failed syntax check" || _fail "no syntax line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite syntax check"

# 7. TLS host override: refused
_url="https://evil.example/spaciousejar/vicine-cli/master/vicine"
printf '#!/bin/sh\nversion_number="1.7.1"\n' > "$_body"
_new_target 1.7.0
cp "$target" "$tmp/before"
_run "$_url"
[ "$_rc" = 1 ] || _fail "foreign host wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "Refusing update source" || _fail "no refusing line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite refusal"

# 8. plaintext override: refused (unauthenticated URL = arbitrary code)
_url="http://raw.githubusercontent.com/spaciousejar/vicine-cli/master/vicine"
_new_target 1.7.0
cp "$target" "$tmp/before"
_run "$_url"
[ "$_rc" = 1 ] || _fail "plaintext host wrongly survived: rc=$_rc"
printf '%s' "$_out" | grep -qF "Refusing update source" || _fail "no refusing line: $_out"
cmp -s "$tmp/before" "$target" || _fail "install was touched despite refusal"

rm -rf "$tmp"
echo "PASS (8 checks)"
