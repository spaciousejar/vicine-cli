#!/bin/sh
# Self-check: every direct hicine/catalogue/update fetch is bounded, and a
# dead host can no longer burn the whole --max-time on a stalled connect —
# every direct curl call carries the connect gate via $curl_to.
# provider_chain fires on curl FAILURE only, so an unbounded call hangs the
# whole interactive search forever instead of falling through to hianime
# ("Re: Zero" sat on "Searching:" for minutes behind a stalling API).
# Usage: sh tests/api_timeouts.sh

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"

# 0. the gate itself is defined in the config block, next to curl_exe
grep -q 'curl_to="--connect-timeout 4"' "$SCRIPT" \
    || _fail "no connect gate: a dead host burns the whole --max-time before failing"

# 1. catalogue fetches (trending/recent/browse/stats/history) are bounded
grep -q '\$curl_exe \$curl_to -sf --max-time 20 "\${API}\${1}"' "$SCRIPT" \
    || _fail "api_fetch() has no --max-time; a stalled endpoint hangs the catalogue menus forever"

# 2. search is bounded — the fallback can never trigger without this
grep -q '\$curl_exe \$curl_to -sf --max-time 20 "\${API}/api/search/\$(henc' "$SCRIPT" \
    || _fail "cmd_search's curl has no --max-time; a slow server-1 hangs instead of falling through to hianime"

# 3. the self-update fetch is bounded
grep -q 'curl \$curl_to -sfL --max-time 20 "\$_repo"' "$SCRIPT" \
    || _fail "update_script's fetch has no --max-time; a dead raw.githubusercontent hangs -U forever"

# 4. every DIRECT curl call (not a wrapper like anidb_curl) carries the gate;
#    wrapper sites resolved via "$@" count once inside the wrapper itself
for _line in $(grep -n 'curl -\|\$curl_exe -' "$SCRIPT" | cut -d: -f1); do
    _line_text=$(sed -n "${_line}p" "$SCRIPT")
    case "$_line_text" in
        *curl_to*|*curl_exe=*|*anidb_curl*|*provider_curl*) ;;
        *) _fail "curl call without the connect gate at line ${_line}: ${_line_text}" ;;
    esac
done

echo "PASS (5 checks)"
