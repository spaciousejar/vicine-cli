#!/bin/sh
# Self-check for the provider-input hardening (vicine-audit findings V-01..V-08):
# the token map is parsed as JSON, so a crafted key can never reach a sed
# program; non-http URLs are refused before curl sees them; the update path
# cannot escape the project directory; a player is one program, not a command
# line; and the destructive commands default to no.
# Usage: sh tests/provider_input.sh

. "$(dirname "$0")/lib.sh"

SRC="$(cd "$(dirname "$0")/.." && pwd)/vicine"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-prov.XXXXXX")"
marker="$tmp/pwned"

# curl stand-in: serves canned token maps and redirects, keyed by $POC_MODE
cat > "$tmp/curl" <<'EOF'
#!/bin/sh
for a in "$@"; do
    case "$a" in
        */api/links*)
            if [ "${POC_MODE:-ok}" = rce ]; then
                printf '%s' '{"tokens":{"x/;e :;/;e touch '"$POC_MARKER"';#":{"ts":"1","sig":"2"}}}'
            else
                printf '%s' '{"tokens":{"tok":{"ts":"1700000000","sig":"deadbeef"}}}'
            fi
            exit 0 ;;
        */go\?*)
            if [ "${POC_MODE:-ok}" = loc ]; then
                printf 'location: --config=%s\r\n' "$POC_MARKER"
            else
                printf 'location: https://cdn.example/real.mp4\r\n'
            fi
            exit 0 ;;
    esac
done
exit 0
EOF
chmod 755 "$tmp/curl"

resolve() { # $1 = POC_MODE; prints resolve_stream_url's output
    POC_MODE="$1" POC_MARKER="$marker" curl_exe="$tmp/curl" SRC="$SRC" \
        VICINE_LIB=1 sh -c '. "$SRC"; resolve_stream_url "http://provider.invalid/x?vcloud=abc"'
}

# 1. hostile token key: no command runs, the worker URL comes back unchanged
rm -f "$marker"
_out="$(resolve rce)"
[ -e "$marker" ] && _fail "sed e-injection executed from the token key"
[ "$_out" = "http://provider.invalid/x?vcloud=abc" ] || _fail "rce case returned: $_out"

# 2. benign token map still resolves through /go
_out="$(resolve ok)"
[ "$_out" = "https://cdn.example/real.mp4" ] || _fail "benign case returned: $_out"

# 3. a non-http Location is not passed on to curl as an option
rm -f "$marker"
_out="$(resolve loc)"
[ -e "$marker" ] && _fail "curl --config ran from a Location header"
[ "$_out" = "http://provider.invalid/x?vcloud=abc" ] || _fail "loc case returned: $_out"

# 4. a provider URL that is not http(s) never reaches curl
_out="$(POC_MODE=ok curl_exe="$tmp/curl" SRC="$SRC" VICINE_LIB=1 sh -c \
    '. "$SRC"; resolve_stream_url "--config=/etc/passwd"')"
[ -z "$_out" ] || _fail "non-http provider URL was echoed: $_out"

# 5. the update path cannot climb out of the project with dot segments
printf '#!/bin/sh\nVICINE_LIB=1 . "%s"\nversion_number="1.7.0"\nupdate_script\n' "$SRC" > "$tmp/sim"
chmod 755 "$tmp/sim"
_out="$(PATH="$tmp:$PATH" VICINE_UPDATE_URL='https://raw.githubusercontent.com/spaciousejar/vicine-cli/../../octocat/Hello-World/master/README' \
    "$tmp/sim" 2>&1)"; _rc=$?
[ "$_rc" = 1 ] || _fail "dot-segment update URL survived (rc=$_rc)"
printf '%s' "$_out" | grep -qF "Refusing update path" || _fail "no refusing line: $_out"

# 6. a player carrying extra words is refused before anything runs
_out="$(VICINE_MENU=sh VICINE_HISTFILE="$tmp/none" VICINE_PLAYER='mpv --script=/tmp/x' \
    "$SRC" -c 2>&1)"; _rc=$?
[ "$_rc" = 1 ] || _fail "multi-word player survived (rc=$_rc)"
printf '%s' "$_out" | grep -qF "Player must be a single program" || _fail "no player line: $_out"

# 7. -C defaults to no; only an explicit y clears
printf '#!/bin/sh\nVICINE_LIB=1 . "%s"\nhistfile="%s/history"\ncmd_clear_history\n' "$SRC" "$tmp" > "$tmp/clear"
chmod 755 "$tmp/clear"
printf 'keep me\n' > "$tmp/history"
"$tmp/clear" < /dev/null >/dev/null 2>&1 || _fail "-C did not exit 0 on cancel"
grep -qF 'keep me' "$tmp/history" || _fail "-C wiped history without confirmation"
printf 'y\n' > "$tmp/yes"
"$tmp/clear" < "$tmp/yes" >/dev/null 2>&1 || _fail "-C failed on an explicit y"
[ -s "$tmp/history" ] && _fail "-C kept history after an explicit y"

# 8. --uninstall defaults to no; only an explicit y removes the file
printf '#!/bin/sh\nVICINE_LIB=1 . "%s"\nhistfile="%s/none"\nuninstall_self\n' "$SRC" "$tmp" > "$tmp/victim"
chmod 755 "$tmp/victim"
"$tmp/victim" < /dev/null >/dev/null 2>&1 || _fail "--uninstall did not exit 0 on cancel"
[ -e "$tmp/victim" ] || _fail "--uninstall removed the script without confirmation"
"$tmp/victim" < "$tmp/yes" >/dev/null 2>&1 || _fail "--uninstall failed on an explicit y"
[ -e "$tmp/victim" ] && _fail "--uninstall kept the script after an explicit y"

# 9. the download confirms pass remote text as printf arguments, never as the
# format (a "%100000s" title would otherwise rewrite the question)
grep -qF 'Download %s %s of' "$SRC" || _fail "download prompt builds a format from remote text again"

# 10. control bytes are stripped from displayed titles, list newlines kept
_out="$(printf 'A\033[2J\033[1;1HB\tC\rD\nE' | VICINE_LIB=1 SRC="$SRC" sh -c '. "$SRC"; hdec')"
[ "$_out" = "$(printf 'A[2J[1;1HB\tCD\nE')" ] || _fail "hdec did not strip control bytes: $_out"

rm -rf "$tmp"
echo "PASS (10 checks)"
