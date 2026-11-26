#!/bin/sh
# Self-check for cmd_search's hyphen retry: the hicine API matches titles
# literally, so "spider man" comes back empty while "spider-man" has hits.
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
tmpfile5="$tmp/t.json"
printf '%s' '{"items":[{"id":"spider","kind":"movie","title":"Spider-Man"}]}' > "$hits"
printf '{}' > "$tmpfile5"

# fake curl: "spider-man" and "superman" have hits, nothing else; record every
# /hapi/search URL it asked for, and write the body to the -o target
log="$tmp/urls"
all_log="$tmp/all_urls"
: > "$all_log"
curl() {
    _url='' _out=''
    for a in "$@"; do
        case "$a" in
            *hicine.biz/hapi/*) printf '%s\n' "$a" >> "$all_log" ;;
        esac
        case "$a" in
            *hicine.biz/hapi/search*) printf '%s\n' "$a" >> "$log"; _url="$a" ;;
            -o) ;;
            *) [ -n "$_url" ] && [ -z "$_out" ] && _out="$a" ;;
        esac
    done
    [ -n "$_out" ] || return 0
    case "$_url" in
        *spider-man*|*superman*) cp "$hits" "$_out" ;;
        *) printf '{"items":[]}' > "$_out" ;;
    esac
}

info() { :; }
warn() { echo "WARN: $*" >&2; }
show_info() { printf 'info\n'; }
prompt_action() { printf 'prompt_action\n'; }
provider_chain() { printf 'chain:%s:%s\n' "$1" "$2"; return 0; }

curl_exe=curl
HICINE_BASE="https://hicine.biz"
info_only=1
download_all_mode=0

# 1. spaced query misses, hyphenated query hits -> the retry plays the pick
out="$(cmd_search 'spider man')"
[ "$out" = "info" ] || _fail "retry did not reach the pick; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || _fail "expected two search requests; got: $(cat "$log")"
grep -q 'spider%20man' "$log" || _fail "first request did not carry the spaced query: $(cat "$log")"
grep -q 'spider-man' "$log" || _fail "second request did not carry the hyphenated query: $(cat "$log")"
grep -q '/hapi/t?c=spider' "$all_log" || _fail "picked item was not enriched via /hapi/t: $(cat "$all_log")"

# 2. hyphenated miss, de-spaced hit: "super man" only exists as "superman"
: > "$log"
out="$(cmd_search 'super man')"
[ "$out" = "info" ] || _fail "de-spaced retry did not reach the pick; got: $out"
grep -q 'q=superman&page=1$' "$log" || _fail "no request carried the de-spaced query: $(cat "$log")"
[ "$(wc -l < "$log" | tr -d ' ')" = 3 ] || _fail "expected three search requests; got: $(cat "$log")"

# 3. no whitespace -> one request only, no pointless retry
: > "$log"
out="$(cmd_search 'spiderman')"
[ "$out" = "chain:spiderman:no confident match" ] || _fail "single-word miss must fall straight to the chain; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "single-word query was retried: $(cat "$log")"

# 4. cancel on a shown picker stops before the retry
select_item() { return 2; }
: > "$log"
out="$(cmd_search 'spider-man')"
[ -z "$out" ] || _fail "cancel must return quietly; got: $out"
[ "$(wc -l < "$log" | tr -d ' ')" = 1 ] || _fail "cancel still retried: $(cat "$log")"

# 5. a dead API must fall through to the fallback provider, not die. The read
#    path hicine_fetch would exit here; the retry loop needs hicine_get instead.
curl() { return 22; }
info_only=0
out="$(cmd_search 'batman')"
[ "$out" = "chain:batman:API unreachable" ] || _fail "API outage did not fall through to chain: $out"

# 6. nonsense query with unrelated API hits must not pick a popular title
log="$tmp/urls2"; all_log="$tmp/all_urls2"; : > "$all_log"
curl() {
    _url='' _out=''
    for a in "$@"; do
        case "$a" in *hicine.biz/hapi/*) printf '%s\n' "$a" >> "$all_log" ;; esac
        case "$a" in *hicine.biz/hapi/search*) printf '%s\n' "$a" >> "$log"; _url="$a" ;; -o) ;; *) [ -n "$_url" ] && [ -z "$_out" ] && _out="$a" ;; esac
    done
    [ -n "$_out" ] || return 0
    printf '%s' '{"items":[{"id":"tangled","kind":"movie","title":"Tangled"}]}' > "$_out"
}
info_only=1
select_item() { printf 'picked\n'; return 0; }
: > "$log"
out="$(cmd_search 'zzzznotarealtitle')"
[ "$out" = "chain:zzzznotarealtitle:no confident match" ] || _fail "nonsense query should not pick unrelated title; got: $out"

echo "PASS (6 checks)"
