#!/bin/sh
# Self-check for the /hapi title-enrichment path: movie links, episode lists,
# whole-season archives, one fetch per group, and lazy token resolution.
# Stubbed. Usage: sh tests/hicine_api.sh
# shellcheck disable=SC2034  # globals below are read by the sourced helpers

. "$(dirname "$0")/lib.sh"
load_vicine
need hicine_enrich_item hicine_token_url resolve_stream_url

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-hapi.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
tmpfile2="$tmp/item.json"
tmpfile4="$tmp/group.json"
tmpfile5="$tmp/title.json"
HICINE_BASE="https://hicine.biz"
curl_exe=curl
curl_to=""
quality=best
tmpdir="$tmp"
LOG="$tmp/calls"
: > "$LOG"

# A file, not a shell variable: resolve_stream_url runs in command substitution,
# so a counter there would never reach the parent shell.
_calls() { tr '\n' ' ' < "$LOG"; }
_reset() { : > "$LOG"; }
_count() { grep -c "^$1" "$LOG" 2>/dev/null || true; }

# fake curl: each group token carries its own episode set; host/go tokens
# resolve to per-token URLs so variant order is observable.
curl() {
    _url='' _out=''
    for a in "$@"; do
        case "$a" in
            https://hicine.biz/hapi/*) _url="$a" ;;
            -o) ;;
            *) [ -n "$_url" ] && [ -z "$_out" ] && _out="$a" ;;
        esac
    done
    [ -n "$_out" ] || return 0
    case "$_url" in
        */hapi/t?c=*) cp "$tmp/t.json" "$_out" ;;
        */hapi/g?k=gz*)
            printf 'g:gz\n' >> "$LOG"
            printf '{"items":[{"ep":null,"hosts":[{"k":"hz"}]}]}' > "$_out" ;;
        */hapi/g?k=*)
            _gk="${_url##*k=}"
            printf 'g:%s\n' "$_gk" >> "$LOG"
            case "$_gk" in
                gs1a|gs1b|ga|g480|g1080) printf '{"items":[{"ep":1,"hosts":[{"k":"h%s"}]},{"ep":2,"hosts":[{"k":"h%s"}]}]}' "$_gk" "$_gk" > "$_out" ;;
                gb) printf '{"items":[{"ep":2,"hosts":[{"k":"h%s"}]}]}' "$_gk" > "$_out" ;;
                *)  printf '{"items":[]}' > "$_out" ;;
            esac ;;
        */hapi/dl?k=multi)
            printf 'dl:multi\n' >> "$LOG"
            printf '{"options":[{"kind":"direct","k":"dead"},{"kind":"direct","k":"live"}]}' > "$_out" ;;
        */hapi/dl?k=bad*)
            printf 'dl:bad\n' >> "$LOG"; return 1 ;;
        */hapi/dl?k=*)
            _hk="${_url##*k=}"; _hk="${_hk%%&*}"
            printf 'dl:%s\n' "$_hk" >> "$LOG"
            printf '{"options":[{"kind":"direct","k":"o%s"}]}' "$_hk" > "$_out" ;;
        */hapi/go?k=dead*)
            printf 'go:dead\n' >> "$LOG"; : > "$_out"; return 1 ;;
        */hapi/go?k=*)
            _ok="${_url##*k=}"; _ok="${_ok%%&*}"
            printf 'go:%s\n' "$_ok" >> "$LOG"
            printf '{"url":"https://cdn.test/%s.mkv"}' "$_ok" > "$_out" ;;
    esac
}

# 1. movie: each quality group becomes a lazy token row, in source order, so
#    show_info and quality menus never walk the token chain.
printf '%s' '{"kind":"movie","groups":[{"season":null,"quality":"480p","size":"400MB","k":"g480"},{"season":null,"quality":"1080p","size":"2GB","k":"g1080"}]}' > "$tmp/t.json"
printf '%s' '{"title":"Movie","contentType":"movie","url_slug":"m"}' > "$tmpfile2"
_reset
hicine_enrich_item || _fail "movie enrichment failed"
[ "$(jq -r '.links' "$tmpfile2")" = "$(printf 'hapi:g480:-,480p,400MB\nhapi:g1080:-,1080p,2GB')" ] || _fail "movie links: $(jq -r '.links' "$tmpfile2")"
[ ! -s "$LOG" ] || _fail "movie enrichment made network calls: $(_calls)"
show_info | grep -q '480p' || _fail "show_info missing movie quality"
show_info | grep -q '1080p' || _fail "show_info missing movie quality"
[ ! -s "$LOG" ] || _fail "show_info made network calls: $(_calls)"

# 2. a stored movie token resolves through g -> dl -> go only when played.
_reset
_u="$(resolve_stream_url "hapi:g480:-")"
[ "$_u" = "https://cdn.test/ohg480.mkv" ] || _fail "lazy movie token resolved to: $_u"
[ "$(_count g:)" = 1 ] && [ "$(_count dl:)" = 1 ] && [ "$(_count go:)" = 1 ] || _fail "lazy token chain: $(_calls)"

# 3. requested quality absent still lists every available quality (no dead end)
printf '%s' '{"kind":"movie","groups":[{"season":null,"quality":"1080p","size":"2GB","k":"g1080"}]}' > "$tmp/t.json"
printf '%s' '{"title":"Movie","contentType":"movie","url_slug":"m"}' > "$tmpfile2"
quality=720p
hicine_enrich_item || _fail "quality fallback failed"
[ "$(jq -r '.links' "$tmpfile2")" = "hapi:g1080:-,1080p,2GB" ] || _fail "quality fallback links: $(jq -r '.links' "$tmpfile2")"
quality=best

# 4. series: per-episode lines carry all quality groups; duplicate group is
#    collapsed; a whole-season archive is emitted for the zip group.
printf '%s' '{"kind":"series","groups":[{"season":1,"quality":"720p","size":"1GB","k":"gs1a"},{"season":1,"quality":"720p","size":"1GB","k":"gs1a"},{"season":1,"quality":"1080p","size":"2GB","k":"gs1b"},{"season":2,"quality":"720p","size":"2GB","k":"gz2"}]}' > "$tmp/t.json"
printf '%s' '{"title":"Series","contentType":"series","url_slug":"s"}' > "$tmpfile2"
_reset
hicine_enrich_item || _fail "series enrichment failed"
[ "$(jq -r '.season_1' "$tmpfile2" | grep -c '^Episode')" = 2 ] || _fail "season_1 episode lines: $(jq -r '.season_1' "$tmpfile2")"
[ "$(qualities_of "$(jq -r '.season_1' "$tmpfile2")" | tr '\n' ' ')" = "1080p 720p " ] || _fail "season_1 qualities: $(qualities_of "$(jq -r '.season_1' "$tmpfile2")")"
[ "$(jq -r '.season_1' "$tmpfile2" | grep -c '^Episode 1 : .* : ')" = 1 ] || _fail "season_1 variants not merged: $(jq -r '.season_1' "$tmpfile2")"
[ "$(jq -r '.season_2' "$tmpfile2" | grep -c '^Season 2 :')" = 1 ] || _fail "season_2 archive line: $(jq -r '.season_2' "$tmpfile2")"
jq -r '.season_zip' "$tmpfile2" | grep -q '^Season 2 : hapi:gz2:-,2GB,720p' || _fail "season_zip missing archive token: $(jq -r '.season_zip' "$tmpfile2")"
# one /hapi/g per distinct group, and no dl/go at enrichment time
[ "$(_count g:)" = 3 ] || _fail "expected 3 group fetches, got: $(_calls)"
[ "$(_count dl:)" = 0 ] && [ "$(_count go:)" = 0 ] || _fail "enrichment resolved media URLs: $(_calls)"
show_info | grep -q 'Season 2.*(archive)' || _fail "archive season shown as 0 episodes"
[ "$(_count g:)" = 3 ] || _fail "show_info refetched groups: $(_calls)"

# 5. -q picks the matching series variant and resolves only that token.
_reset
_parsed="$(parse_episodes "$(jq -r '.season_1' "$tmpfile2")" 1080p)"
[ "$(printf '%s\n' "$_parsed" | wc -l | tr -d ' ')" = 2 ] || _fail "-q 1080p episode count: $_parsed"
printf '%s\n' "$_parsed" | awk -F'\t' '$1==1 {print $2}' | grep -q '^hapi:gs1b:1$' || _fail "-q 1080p picked wrong variant: $_parsed"
_u="$(resolve_stream_url "$(printf '%s\n' "$_parsed" | awk -F'\t' '$1==1 {print $2}')")"
[ "$_u" = "https://cdn.test/ohgs1b.mkv" ] || _fail "-q 1080p resolved to: $_u"

# 6. a failed token request must leave no old JSON for the caller to parse.
printf '%s' '{"options":[{"kind":"direct","k":"stale"}]}' > "$tmpfile5"
_stale_url="$(hicine_host_url bad)"
[ -z "$_stale_url" ] || _fail "failed /hapi/dl reused a stale option: $_stale_url"

# 7. archive-only season: group .k is null and the usable token lives in
#    .zip[0].k. A null first field would shift quality/size and emit a dead
#    "hapi:720p" token; the zip token must be used instead.
printf '%s' '{"kind":"series","groups":[{"season":3,"quality":"720p","size":"7.1GB","k":null,"zip":[{"k":"gz3"}]}]}' > "$tmp/t.json"
printf '%s' '{"title":"Series","contentType":"series","url_slug":"s"}' > "$tmpfile2"
_reset
hicine_enrich_item || _fail "archive-only enrichment failed"
jq -r '.season_3' "$tmpfile2" | grep -q '^Season 3 : hapi:gz3:-,7.1GB,720p$' || _fail "archive-only season token: $(jq -r '.season_3' "$tmpfile2")"
_u="$(resolve_stream_url "hapi:gz3:-")"
[ "$_u" = "https://cdn.test/ohz.mkv" ] || _fail "archive-only token resolved to: $_u"

# 8. a dead first /hapi/go option must not discard the whole host: try the
#    remaining direct options on that host before moving on.
_reset
_u="$(hicine_host_url multi)"
[ "$_u" = "https://cdn.test/live.mkv" ] || _fail "host option fallback: $_u"
[ "$(_count go:)" = 2 ] || _fail "host option fallback go calls: $(_calls)"

# 9. keep the contributor guide in sync with the lazy chain. The docs must
#    state that g/dl/go run at play time. The docs must also state that -i
#    and the quality menus skip token requests.
_hacking="$(dirname "$0")/../hacking.md"
grep -qF 'runs at play/download time, not here' "$_hacking" \
    || _fail "hacking.md no longer documents lazy token resolution"
grep -qF 'make no token requests' "$_hacking" \
    || _fail "hacking.md no longer states -i and menus skip token requests"

echo "PASS (20 checks)"
