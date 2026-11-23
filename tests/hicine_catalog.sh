#!/bin/sh
# Regressions for the /hapi catalogue entry points:
# - -b anime is the only path that ever stamped contentType=anime, which gates
#   the hianime gap-fill retry in download_all_item.
# - /hapi/home serves one mixed `trending` row, so -t movies/-t series must
#   filter the mapped list instead of just relabelling it.
# Stubbed. Usage: sh tests/hicine_catalog.sh
# shellcheck disable=SC2034

. "$(dirname "$0")/lib.sh"
load_vicine
need hicine_map_list cmd_browse cmd_trending

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-catalog.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
tmpfile="$tmp/list.json"; tmpfile2="$tmp/item.json"
browse_type=""; browse_page=1; browse_limit=1000
download_all_mode=0; info_only=0
FIXTURE=""

hicine_fetch() { cp "$FIXTURE" "$2"; }
select_item() { jq -c '.[0]' "$tmpfile" > "$tmpfile2"; }
hicine_enrich_item() { :; }
prompt_action() { :; }
show_info() { :; }

_types() { jq -r '.[].contentType' "$tmpfile" | tr '\n' ' '; }

printf '%s' '{"items":[{"id":"a1","title":"Anime One","kind":"series"},{"id":"a2","title":"Movie Two","kind":"movie"}]}' > "$tmp/browse.json"
FIXTURE="$tmp/browse.json"; browse_type="type=anime"
cmd_browse anime
[ "$(_types)" = "anime anime " ] || _fail "anime browse contentType: $(_types)"

FIXTURE="$tmp/browse.json"; browse_type="type=movie"
cmd_browse movies
[ "$(_types)" = "series movie " ] || _fail "movie browse lost kind mapping: $(_types)"

printf '%s' '{"trending":[{"id":"t1","title":"Film","kind":"movie"},{"id":"t2","title":"Show","kind":"series"},{"id":"t3","title":"Film 2","kind":"movie"}]}' > "$tmp/home.json"
FIXTURE="$tmp/home.json"
cmd_trending movies
[ "$(_types)" = "movie movie " ] || _fail "trending movies not filtered: $(_types)"
cmd_trending series
[ "$(_types)" = "series " ] || _fail "trending series not filtered: $(_types)"
cmd_trending
[ "$(_types)" = "movie series movie " ] || _fail "unfiltered trending changed: $(_types)"

# A hicine search row has no anime field. The mapper must therefore emit only
# series/movie, which is why README limits the hianime gap-fill retry to the
# -b anime path instead of promising it for search-found anime.
printf '%s' '{"items":[{"id":"s1","title":"One Piece","kind":"series"},{"id":"s2","title":"Film","kind":"movie"}]}' > "$tmp/search.json"
hicine_map_list "$tmp/search.json" items
[ "$(jq -r '.[].contentType' "$tmp/search.json" | tr '\n' ' ')" = "series movie " ] \
    || _fail "search mapping invented an anime marker"
# Keep the docs and the gap-fill gate in sync with the API shape. A wider gate
# could download a wrong-provider title into a non-anime folder.
_readme="$(dirname "$0")/../README.md"
_script="$(dirname "$0")/../vicine"
grep -qF 'The hicine API has no anime field.' "$_readme" \
    || _fail "README dropped the no-anime-field limit"
grep -qF 'Only `-b anime` marks items as anime' "$_readme" \
    || _fail "README dropped the -b anime gap-fill path"
grep -qF 'contentType // ""' "$_script" \
    || _fail "hianime gap-fill gate no longer checks contentType"
echo "PASS (8 checks)"
