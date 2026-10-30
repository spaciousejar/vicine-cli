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
API="$(_cfg API)"
anime_base="$(_cfg anime_base)"
anime_search_api="$(_cfg anime_search_api)"
anime_episodes_api="$(_cfg anime_episodes_api)"
vicine_ua="$(_cfg vicine_ua)"
curl_exe="$(_cfg curl_exe)"
# the anime endpoints are templates that reference ${anime_base}
anime_search_api="$(printf '%s' "$anime_search_api" | sed "s|\${anime_base}|$anime_base|")"
anime_episodes_api="$(printf '%s' "$anime_episodes_api" | sed "s|\${anime_base}|$anime_base|")"

# hicine — the catalogue API answers a JSON array for /api/search/<query>
_hic=""
_try=1
while [ "$_try" -le 3 ]; do
    _hic="$(curl -sf --max-time 20 "${API}/api/search/batman" 2>/dev/null)"
    [ -n "$_hic" ] && break
    _try=$(( _try + 1 ))
    sleep 3
done
if [ -z "$_hic" ]; then
    echo "BLOCKED: hicine API did not answer after 3 tries"
    exit 0
fi
_n="$(printf '%s' "$_hic" | jq 'length' 2>/dev/null)"
case "${_n:-}" in
    ''|*[!0-9]*)
        _fail "hicine search did not answer with a JSON array: $(printf '%s' "$_hic" | head -c 200)"
        ;;
esac
[ "$_n" -ge 1 ] || _fail "hicine search returned no rows"
echo "OK    hicine search            $_n rows"

# A spaced query has to survive the retry cmd_search makes. server-1 matches
# titles literally: "spider man" answered 0 rows when "spider-man" answered 16.
# Both go through henc, so a broken encoder shows up here too.
_q='spider man'
_rows=0
for _c in "$_q" "$(printf '%s' "$_q" | tr -s '[:space:]' '-')"; do
    _r="$(curl -sf --max-time 20 "${API}/api/search/$(henc "$_c")" 2>/dev/null | jq 'length' 2>/dev/null)"
    case "${_r:-}" in
        ''|*[!0-9]*) _fail "search for '$_c' did not answer with a JSON array" ;;
    esac
    _rows=$(( _rows + _r ))
done
[ "$_rows" -ge 1 ] || _fail "neither 'spider man' nor 'spider-man' returned a row"
echo "OK    hicine spaced query      $_rows rows"

# The resolver: a payload link has to walk to a real stream URL. Walked over
# the first few items with links so one dead bucket entry does not fail the
# run — that is exactly what movie_playable does per title.
quality=best
_ok=""
_i=0
while [ "$_i" -lt 5 ]; do
    _links="$(printf '%s' "$_hic" | jq -r --argjson i "$_i" '.[$i].links // empty' 2>/dev/null)"
    _i=$(( _i + 1 ))
    [ -n "$_links" ] || continue
    _ok="$(movie_playable "$(parse_links "$_links")" 2>/dev/null)"
    [ -n "$_ok" ] && break
done
[ -n "$_ok" ] || _fail "no hicine link resolved to a playable URL"
echo "OK    hicine resolver          ${_ok%%\?*}"

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
