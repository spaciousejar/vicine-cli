#!/bin/sh
# shellcheck disable=SC2034  # `quality` is read by the sourced anime_pick_quality
# Self-check for the anime provider plumbing the other suites never touched
# (issue #53): the endpoint templates, the zoko_xor decoder and the quality
# picker. zoko_xor and anime_pick_quality are pure; the templates are checked
# statically because the config block sits after the VICINE_LIB early return.
# Usage: sh tests/anime_plumbing.sh

SRC="$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
VICINE_LIB=1 . "$SRC"

_fail() { echo "FAIL: $1" >&2; exit 1; }
command -v zoko_xor >/dev/null 2>&1 || _fail "zoko_xor missing from vicine"
command -v anime_pick_quality >/dev/null 2>&1 || _fail "anime_pick_quality missing from vicine"

# Endpoints are assembled as ${tmpl%"%s"}$value, so each template must end in
# exactly one literal %s. A second %s (or a stray %) would silently shift the
# substitution — and would become a printf format if the construction ever
# went back to printf (#38).
tmpl() { # name -> the string value of the `name="..."` line in the source
    _line="$(grep -E "^${1}=\"" "$SRC" | head -1)"
    [ -n "$_line" ] || _fail "$1 not found in $SRC"
    _val="${_line#*=\"}"; printf '%s' "${_val%\"}"
}
for _v in anime_search_api anime_episodes_api anime_servers_api; do
    _t="$(tmpl "$_v")"
    case "$_t" in
        *%s) ;;
        *) _fail "$_v must end in a literal %s (got: $_t)" ;;
    esac
    case "${_t%"%s"}" in
        *%s*) _fail "$_v has more than one %s (got: $_t)" ;;
    esac
done

# and the call sites must use that construction, not printf with the template
grep -qF 'printf "$anime_' "$SRC" && _fail "a call site went back to printf with the template"
for _v in anime_search_api anime_episodes_api anime_servers_api; do
    grep -qF "\${${_v}%\"%s\"}" "$SRC" || _fail "$_v is not assembled via \${${_v}%\"%s\"}"
done

# zoko_xor: base64 -> od bytes -> XOR against otaku-embed-v1. The fixture is a
# known plaintext (what the page's window.__P decodes to); a wrong key or byte
# order just yields an empty src rather than an error, so assert the exact text.
PLAIN='{"src":"https://hls.1embed.buzz/master.m3u8?token=abc"}'
BLOB='FFYSGRYPX08KERBdBQtAWwkHBgNUCA8HAUlYUxoOG0QYTBYZBxdKQEVEV0sVBB5IC1ADBwcPCw=='
[ "$(printf '%s' "$BLOB" | zoko_xor)" = "$PLAIN" ] \
    || _fail "zoko_xor did not decode the known fixture"
# one flipped base64 char must not still produce the plaintext
BAD='GFYSGRYPX08KERBdBQtAWwkHBgNUCA8HAUlYUxoOG0QYTBYZBxdKQEVEV0sVBB5IC1ADBwcPCw=='
[ "$(printf '%s' "$BAD" | zoko_xor)" != "$PLAIN" ] \
    || _fail "zoko_xor ignored a corrupted input"
# macOS od pads its line with trailing blanks. GNU od does not pad. Splitting
# the padded list on blanks yields an empty element. The key cycle then has
# 15 bytes instead of 14, so every byte after the first cycle decodes to
# garbage. The decoder must ignore the padding. The macOS CI leg found this.
ANIME_ZOKO_NUMS_SAVE="$ANIME_ZOKO_NUMS"
ANIME_ZOKO_NUMS='111 116  97 107 117  45 101 109  98 101 100  45 118  49        '
[ "$(printf '%s' "$BLOB" | zoko_xor)" = "$PLAIN" ] \
    || _fail "zoko_xor broke on a padded key list (macOS od)"
ANIME_ZOKO_NUMS="$ANIME_ZOKO_NUMS_SAVE"

# anime_pick_quality: best = first line, worst = last resolution line,
# a named quality = first substring match, no match = first line.
LINKS='1080p>https://a/1080.m3u8
720p>https://a/720.m3u8
360p>https://a/360.m3u8'
quality=best
[ "$(anime_pick_quality "$LINKS")" = "1080p>https://a/1080.m3u8" ] || _fail "best pick"
quality=worst
[ "$(anime_pick_quality "$LINKS")" = "360p>https://a/360.m3u8" ]  || _fail "worst pick"
quality=720p
[ "$(anime_pick_quality "$LINKS")" = "720p>https://a/720.m3u8" ]   || _fail "named quality pick"
quality=480p
[ "$(anime_pick_quality "$LINKS")" = "1080p>https://a/1080.m3u8" ] || _fail "unmatched quality -> first line"

# -A -D saves to <title>/season-N/SNE##. A split-cour anime lists 1..N twice
# under different internal ids (anidb_episodes dedups the whole row, not the
# number), so the second run of each number is a DIFFERENT episode: with a
# fixed season-1 it landed on the first one's file and dl_find skipped it, so
# the whole second cour was silently never downloaded. Both halves are inline
# in cmd_anime/anime_play_episode, so they are asserted on the source.
grep -qF 'n[$1]++; print $1' "$SRC" \
    || _fail "the episode list is not tagged with which run of a number it is"
grep -qF 'anime_play_episode "$_ep" "$_occ"' "$SRC" \
    || _fail "the -D loop does not pass the occurrence through"
grep -qF 'season-${_ep_occ}/S${_ep_occ}E${_epnum}' "$SRC" \
    || _fail "anime -D still writes a fixed season-1 folder"

echo "PASS (22 checks)"
