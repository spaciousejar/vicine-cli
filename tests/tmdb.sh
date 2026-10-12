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

echo "PASS (6 checks)"