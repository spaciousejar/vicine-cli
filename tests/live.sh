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

SRC="$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
VICINE_LIB=1 . "$SRC"

_fail() { echo "FAIL: $1" >&2; exit 1; }

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

echo "PASS (3 checks)"
