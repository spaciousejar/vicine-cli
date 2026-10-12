#!/bin/sh
# Self-check for the TMDB provider's pure parts — tmdb_search's row format and
# tmdb_pick's ranking.
#
# tmdb_pick exists because TMDB ranks "Bangalore Naatkal" above "Bangalore
# Days" for the query "bangalore days": taking the first search row plays the
# wrong film, silently.
#
# tmdb_search itself is network-backed and not asserted here (it would make the
# suite depend on TMDB being up and not rate-limiting); the patterns it uses
# are pinned by the source assertions at the bottom.
# Usage: sh tests/tmdb.sh

SCRIPT="$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
VICINE_LIB=1 . "$SCRIPT"

_fail() { echo "FAIL: $1" >&2; exit 1; }
command -v tmdb_pick >/dev/null 2>&1 || { echo "tmdb_pick missing from vicine" >&2; exit 1; }

# TMDB's real ranking for "bangalore days" — the wrong film comes first
ROWS='1085271	Bangalore Naatkal
268660	Bangalore Days'

[ "$(printf '%s\n' "$ROWS" | tmdb_pick "bangalore days")" = "268660" ] \
    || _fail "exact title should win over TMDB ranking"

# punctuation and case must not block an exact match
[ "$(printf '%s\n' "$ROWS" | tmdb_pick "Bangalore  Days!")" = "268660" ] \
    || _fail "normalisation failed: case/punctuation should still match"

# a query the title starts with still resolves (no exact row exists)
[ "$(printf '123\tSome Other Film\n456\tPremalu\n' | tmdb_pick "Premalu 2024")" = "456" ] \
    || _fail "prefix fallback did not pick Premalu"

# nothing matches -> empty, so the caller can fall back rather than guess
[ -z "$(printf '123\tTotally Different\n' | tmdb_pick "Premalu")" ] \
    || _fail "unmatched query should return empty"

# a short title must not prefix-match everything
[ -z "$(printf '99\tPre\n' | tmdb_pick "Premalu")" ] \
    || _fail "a 4-char title should not prefix-match"

# the scrape is anchored on the result card, so the sidebar lists (which share
# the /movie/<id> shape) cannot be picked up as results
grep -qF 'href="/movie/[0-9]+"><h2[^>]*><span>[^<]+' "$SCRIPT" \
    || _fail "tmdb_search lost its result-card anchor"

# --- the TMDB_API_KEY branch -------------------------------------------------
# With a key, tmdb_search uses the official v3 API instead of scraping. A live
# call is not testable here (no valid key in CI), so the branch is driven with
# a stubbed curl that returns TMDB's real response shape.
grep -qF 'tmdb_api_key="${TMDB_API_KEY:-}"' "$SCRIPT" \
    || _fail "the key is not read from the environment"
grep -qF 'api_key=${tmdb_api_key}' "$SCRIPT" \
    || _fail "the key branch does not call the v3 API"

fake="$(mktemp)"
cat > "$fake" <<'CURLSTUB'
#!/bin/sh
for a in "$@"; do
  case "$a" in
    *api_key=*)
      cat <<'J'
{"page":1,"results":[
 {"id":1085271,"title":"Bangalore Naatkal","release_date":"1996-02-09"},
 {"id":268660,"title":"Bangalore Days","release_date":"2014-01-30"},
 {"id":999,"title":"Bangalore Days 2","release_date":null}]}
J
      exit 0 ;;
  esac
done
exit 1
CURLSTUB
chmod +x "$fake"

curl_exe="$fake"
tmdb_api_key="test-key"

got="$(tmdb_search "bangalore days" | head -1)"
[ "$got" = "1085271	Bangalore Naatkal" ] \
    || _fail "API branch did not parse results, got: '$got'"

# the ranking rule has to hold on the API path too — this is the case the
# provider exists for
[ "$(tmdb_search "bangalore days" | tmdb_pick "bangalore days")" = "268660" ] \
    || _fail "API branch did not pick the exact title over TMDB's ranking"

rm -f "$fake"

# --- the chain must survive an empty anime search ---------------------------
# cmd_anime used to die on an empty search, and die exits the whole script, so
# an hianime miss skipped the TMDB provider entirely — the fallback that only
# runs when anime finds nothing was the one case it never ran in.
grep -qF '_in_chain=1' "$SCRIPT" || _fail "provider_chain does not set _in_chain"
grep -qF '[ -n "$_in_chain" ] && return 1' "$SCRIPT" \
    || _fail "cmd_anime does not return on an empty search inside the chain"

anidb_search() { :; }          # an hianime miss
_in_chain=1
cmd_anime "no such anime here" >/dev/null 2>&1
[ "$?" = 1 ] || _fail "cmd_anime should return 1 in the chain, not die"

# and as the -A entry point it must still be a hard stop
( _in_chain=""; cmd_anime "no such anime here" >/dev/null 2>&1 )
[ "$?" = 1 ] || _fail "-A should still exit 1 when anime finds nothing"

# --- play_url must always have a return code -------------------------------
# _chain_played is decided from _pl_rc at the end of play_url. The detached
# branches never set it, so the tail ran `[: : integer expected` and the flag
# stayed unset — which is the default playback path, so every detached play
# looked like "nothing started" and the chain reported no results.
grep -qF '_pl_rc=0' "$SCRIPT" || _fail "play_url no longer initialises _pl_rc"

# and it has to be set before the branch, not only inside some of them
_pl_head="$(sed -n '/^play_url() {/,/case "\$player_function"/p' "$SCRIPT")"
case "$_pl_head" in
    *_pl_rc=0*) ;;
    *) _fail "_pl_rc is not initialised before play_url's case" ;;
esac

# a detached launch must mark the chain as having played something
info() { :; }
warn() { :; }
ok() { :; }
player() { return 0; }
check_stream_url() { return 0; }
player_function=mpv; no_detach=0; exit_after_play=0; _chain_played=""

# a detached launch must mark the chain as having played something. Not in a
# subshell: play_url sets a global, and a subshell would swallow it — the same
# mistake this test exists to prevent.
play_url "http://x/y.m3u8" "t" "" >/dev/null 2>&1
[ -n "$_chain_played" ] || _fail "a detached play did not set _chain_played"

echo "PASS (15 checks)"