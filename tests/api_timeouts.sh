#!/bin/sh
# Self-check: every direct hicine/catalogue/update fetch is bounded.
# provider_chain fires on curl FAILURE only, so an unbounded call hangs the
# whole interactive search forever instead of falling through to hianime
# ("Re: Zero" sat on "Searching:" for minutes behind a stalling API).
# Usage: sh tests/api_timeouts.sh

SCRIPT="$(dirname "$0")/../vicine"
_fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. catalogue fetches (trending/recent/browse/stats/history) are bounded
grep -q '\$curl_exe -sf --max-time 20 "\${API}\${1}"' "$SCRIPT" \
    || _fail "api_fetch() has no --max-time; a stalled endpoint hangs the catalogue menus forever"

# 2. search is bounded — the fallback can never trigger without this
grep -q '\$curl_exe -sf --max-time 20 "\${API}/api/search/\${_encoded}"' "$SCRIPT" \
    || _fail "cmd_search's curl has no --max-time; a slow server-1 hangs instead of falling through to hianime"

# 3. the self-update fetch is bounded
grep -q 'curl -sfL --max-time 20 "\$_repo"' "$SCRIPT" \
    || _fail "update_script's fetch has no --max-time; a dead raw.githubusercontent hangs -U forever"

echo "PASS (3 checks)"
