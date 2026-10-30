#!/bin/sh
# Self-check for cmd_search's hyphen retry: server-1 matches titles literally,
# so "spider man" comes back empty while "spider-man" has hits.
# Usage: sh tests/search_retry.sh
# shellcheck disable=SC2034  # the globals below are read by the sourced cmd_search

# source the real script (VICINE_LIB) rather than sed-ing functions out of it
. "$(dirname "$0")/lib.sh"

load_vicine
need cmd_search

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-search.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
hits="$tmp/hits.json"
tmpfile="$tmp/result.json"
tmpfile2="$tmp/picked.json"
tmpfile3="$tmp/menu.txt"
printf '%s' '[{"title":"Spider-Man","contentType":"movie"}]' > "$hits"

# fake curl: "spider-man" and "superman" have hits, nothing else; record every
# URL it asked for
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
        *spider-man*|*superman*) cp "$hits" "$_out" ;;
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

# 2. hyphenated miss, de-spaced hit: "super man" only exists as "superman"
: > "$log"
out="$(cmd_search 'super man')"
[ "$out" = "info" ] || _fail "de-spaced retry did not reach the pick; got: $out"
grep -q 'search/superman$' "$log" || _fail "no request carried the de-spaced query: $(cat "$log")"
[ "$(wc -l < "$log" | tr -d ' ')" = 3 ] || _fail "expected three search requests; got: $(cat "$log")"

# 3. no whitespace -> one request only, no pointless retry
: > "$log"
out="$(cmd_search 'spiderman')"
[ "$out" = "chain:spiderman:no results" ] || _fail "single-word miss must fall straight to the chain; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "single-word query was retried: $(cat "$log")"

# 4. cancel on the first picker stops before the retry
select_item() { return 2; }
: > "$log"
out="$(cmd_search 'spider man')"
[ -z "$out" ] || _fail "cancel must return quietly; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "cancel still retried: $(cat "$log")"

echo "PASS (4 checks)"
