#!/bin/sh
# shellcheck disable=SC2034  # vicine_ua/curl_exe are read by the sourced anidb_curl
# Live provider smoke test — hits the real hicine and hianime APIs and checks
# that a search still returns rows. The offline suites cover the parsers
# against fixtures, but nothing noticed that a provider changed its payload
# or started serving a challenge shell until a user did.
#
# Network-dependent, so it is skipped unless asked for:
#
#   VICINE_LIVE=1 sh tests/live.sh
#
# A provider that blocks our IP (challenge shell, 403/429) is reported as
# BLOCKED and does not fail the run — a datacentre IP gets soft-blocked
# routinely and that is not a code regression. A provider that answers with
# something the parser cannot read IS a failure: that is the drift this
# test exists to catch.

. "$(dirname "$0")/lib.sh"

SRC="$(dirname "$0")/../vicine"
load_vicine

if [ "${VICINE_LIVE:-}" != 1 ]; then
    echo "SKIP (network test — set VICINE_LIVE=1 to run)"
    exit 0
fi

# The config block sits after the VICINE_LIB early return, so sourcing the
# library leaves the provider settings unset — read them from the source.
_cfg() { sed -n "s/^$1=\"\(.*\)\"\$/\1/p" "$SRC" | head -1; }
HICINE_BASE="$(_cfg HICINE_BASE)"
anime_base="$(_cfg anime_base)"
anime_search_api="$(_cfg anime_search_api)"
anime_episodes_api="$(_cfg anime_episodes_api)"
vicine_ua="$(_cfg vicine_ua)"
curl_exe="$(_cfg curl_exe)"
# the anime endpoints are templates that reference ${anime_base}
anime_search_api="$(printf '%s' "$anime_search_api" | sed "s|\${anime_base}|$anime_base|")"
anime_episodes_api="$(printf '%s' "$anime_episodes_api" | sed "s|\${anime_base}|$anime_base|")"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/vicine-live.XXXXXX")" || exit 1
trap 'rm -rf "$tmpdir"' EXIT

# hicine — the public /hapi API answers {items:[...]} for /hapi/search
_hic="$tmpdir/hicine.json"
_try=1
while [ "$_try" -le 3 ]; do
    curl -sf --max-time 20 -e "${HICINE_BASE}/" "${HICINE_BASE}/hapi/search?q=batman&page=1" -o "$_hic" 2>/dev/null && break
    _try=$(( _try + 1 ))
    sleep 3
done
[ -s "$_hic" ] || { echo "BLOCKED: hicine API did not answer after 3 tries"; exit 0; }
_n="$(jq '.items | length' "$_hic" 2>/dev/null)"
case "${_n:-}" in
    ''|*[!0-9]*)
        _fail "hicine search did not answer with an items array: $(head -c 200 "$_hic")"
        ;;
esac
[ "$_n" -ge 1 ] || _fail "hicine search returned no rows"
echo "OK    hicine search            $_n rows"

# A spaced query has to survive the retry cmd_search makes. The API matches
# titles literally: "spider man" misses where "spider-man" hits. Both go
# through henc, so a broken encoder shows up here too.
_q='spider man'
_rows=0
for _c in "$_q" "$(printf '%s' "$_q" | tr -s '[:space:]' '-')"; do
    curl -sf --max-time 20 -e "${HICINE_BASE}/" "${HICINE_BASE}/hapi/search?q=$(henc "$_c")&page=1" -o "$_hic.tmp" 2>/dev/null || continue
    _r="$(jq '.items | length' "$_hic.tmp" 2>/dev/null)"
    case "${_r:-}" in
        ''|*[!0-9]*) _fail "search for '$_c' did not answer with an items array" ;;
    esac
    _rows=$(( _rows + _r ))
done
[ "$_rows" -ge 1 ] || _fail "neither 'spider man' nor 'spider-man' returned a row"
echo "OK    hicine spaced query      $_rows rows"

# The resolver: walk the first few search hits through /hapi/t -> /hapi/g ->
# /hapi/dl -> /hapi/go to a real stream URL. One dead token must not fail the
# run — that is exactly what hicine_enrich_item does per title.
quality=best
tmpfile2="$tmpdir/hicine-item.json"
tmpfile4="$tmpdir/hicine-group.json"
tmpfile5="$tmpdir/hicine-title.json"
_ok=""
_i=0
while [ "$_i" -lt 5 ]; do
    _hid="$(jq -r --argjson i "$_i" '.items[$i].id // empty' "$_hic" 2>/dev/null)"
    _i=$(( _i + 1 ))
    [ -n "$_hid" ] || continue
    printf '{"id":%s}' "$(printf '%s' "$_hid" | jq -sR '.')" > "$tmpfile2"
    hicine_get "/hapi/t?c=$_hid" "$tmpfile5" || continue
    hicine_enrich_item "$tmpfile5" || continue
    _ok="$(jq -r '.links // empty' "$tmpfile2")"
    [ -n "$_ok" ] && break
done
[ -n "$_ok" ] || _fail "no hicine link resolved to a playable URL"
echo "OK    hicine resolver          ${_ok%%,*}"

# hianime — the anime search. anidb_search dies on a challenge/429 page,
# which means blocked, not broken.
_an="$(anidb_search "one piece" 2>&1)"
_an_rc=$?
if [ "$_an_rc" != 0 ]; then
    case "$_an" in
        *challeng*|*rate-limit*) echo "BLOCKED: hianime served a challenge/rate-limit page"; exit 0 ;;
        *) _fail "hianime search failed: $_an" ;;
    esac
fi
_lines="$(printf '%s\n' "$_an" | grep -c .)"
[ "${_lines:-0}" -ge 1 ] || _fail "hianime search returned no rows"
echo "OK    hianime search           $_lines rows"

# the anime episode listing — the second scraper layer
_id="$(printf '%s\n' "$_an" | head -1 | cut -f1)"
[ -n "$_id" ] || _fail "hianime search row had no id"
_eps="$(anidb_episodes "$_id" 2>/dev/null | grep -c .)"
[ "${_eps:-0}" -ge 1 ] || _fail "hianime episode list came back empty for $_id"
echo "OK    hianime episodes         $_eps episodes"

echo "PASS (5 checks)"
