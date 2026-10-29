#!/bin/sh
# Self-check for cmd_search's hyphen retry: server-1 matches titles literally,
# so "spider man" comes back empty while "spider-man" has hits.
# Usage: sh tests/search_retry.sh
# shellcheck disable=SC2034  # the globals below are read by the sourced cmd_search

# source the real script (VICINE_LIB) rather than sed-ing functions out of it
VICINE_LIB=1 . "$(dirname "$0")/../vicine"
command -v cmd_search >/dev/null 2>&1 || { echo "cmd_search missing from vicine" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-search.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
hits="$tmp/hits.json"
tmpfile="$tmp/result.json"
tmpfile2="$tmp/picked.json"
tmpfile3="$tmp/menu.txt"
printf '%s' '[{"title":"Spider-Man","contentType":"movie"}]' > "$hits"

# fake curl: only the hyphenated query has hits; record every URL it asked for
log="$tmp/urls"
curl() {
    _url='' _out=''
    for a in "$@"; do
        case "$a" in
            */api/search/*) printf '%s\n' "$a" >> "$log"; _url="$a" ;;
            -o) ;;
            *) [ -n "$_url" ] && _out="$a" ;;
        esac
    done
    case "$_url" in
        *spider-man*) cp "$hits" "$_out" ;;
        *) printf '[]' > "$_out" ;;
    esac
}

info() { :; }
warn() { echo "WARN: $*" >&2; }
show_info() { printf 'info\n'; }
prompt_action() { printf 'prompt_action\n'; }
provider_chain() { printf 'chain:%s:%s\n' "$1" "$2"; return 0; }

curl_exe=curl
info_only=1
download_all_mode=0
API="https://api.invalid"

# 1. spaced query misses, hyphenated query hits -> the retry plays the pick
out="$(cmd_search 'spider man')"
[ "$out" = "info" ] || _fail "retry did not reach the pick; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || _fail "expected two search requests; got: $(cat "$log")"
grep -q 'spider%20man' "$log" || _fail "first request did not carry the spaced query: $(cat "$log")"
grep -q 'spider-man' "$log" || _fail "second request did not carry the hyphenated query: $(cat "$log")"

# 2. no whitespace -> one request only, no pointless retry
: > "$log"
out="$(cmd_search 'spiderman')"
[ "$out" = "chain:spiderman:no results" ] || _fail "single-word miss must fall straight to the chain; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "single-word query was retried: $(cat "$log")"

# 3. cancel on the first picker stops before the retry
select_item() { return 2; }
: > "$log"
out="$(cmd_search 'spider man')"
[ -z "$out" ] || _fail "cancel must return quietly; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "cancel still retried: $(cat "$log")"

echo "PASS (3 checks)"
