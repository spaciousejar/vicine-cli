#!/bin/sh
# Self-check for play_season_zip() — the whole-season-archive path in vicine.
#
# Extracted out of prompt_action (which was 234 lines) into a function with a
# two-value contract: 0 = handled the season, 1 = nothing to play. This suite
# pins both halves, plus the candidate ordering (requested quality first, then
# the rest) and the stale-URL fallback that makes the ordering matter.
#
# Network is stubbed: resolve_stream_url returns a fixed mapping and the 1-byte
# probe is replaced by a list of "which candidates are live".
# Usage: sh tests/season_zip.sh

. "$(dirname "$0")/lib.sh"

load_vicine

need play_season_zip

# Globals play_season_zip reads. Sourcing with VICINE_LIB stops before the
# Main section, so the mktemp/dir setup there never ran — the suite makes its
# own, exactly as the functions expect them to look.
tmpfile2="$(mktemp "${TMPDIR:-/tmp}/vicine-sz.XXXXXX")"; tmpfile3="$(mktemp "${TMPDIR:-/tmp}/vicine-sz.XXXXXX")"
quality=best; download_dir="$(mktemp -d "${TMPDIR:-/tmp}/vicine-sz.XXXXXX")"
histfile="$(mktemp "${TMPDIR:-/tmp}/vicine-sz.XXXXXX")"
# shellcheck disable=SC2034  # read by the sourced play_season_zip
exit_after_play=0

# stubs: PROBE_OK lists the candidate URLs that resolve; each becomes a .zip so
# the download branch is the one under test
PROBE_OK=""
resolve_stream_url() {
    case " $PROBE_OK " in
        *" $1 "*) printf 'https://cdn.test/%s.zip' "$(printf '%s' "$1" | sed 's|.*/||')" ;;
        *)         return 1 ;;
    esac
}
curl() { return 0; }          # the 1-byte probe always passes
play_url() { PLAYED="$2"; return 0; }
do_download() { DOWNLOADED="$2"; return 0; }
update_history() { :; }
warn() { :; }
info() { :; }
PLAYED=""; DOWNLOADED=""

# a .season_zip with two variants for season 1: the label/quality pair is what
# the ordering below keys off
ZIP='Season 1 : https://w.test/a,480p,Season1Packed,480p : https://w.test/b,1080p,Season1Packed,1080p
Season 2 : https://w.test/c,720p,Season2Packed,720p'

# --- contract: nothing to play -> 1 ------------------------------------------
printf '{"season_zip": ""}' > "$tmpfile2"
play_season_zip "T" "s" 1 >/dev/null 2>&1
[ $? -eq 1 ] || _fail "empty season_zip should return 1"

printf '{"season_zip": "Season 9 : https://w.test/z,720p,x,720p"}' > "$tmpfile2"
play_season_zip "T" "s" 1 >/dev/null 2>&1
[ $? -eq 1 ] || _fail "a zip with no line for season 1 should return 1"

# --- contract: handled -> 0, and the ZIP extension routes to download --------
printf '%s' "$ZIP" | jq -Rs '{season_zip: .}' > "$tmpfile2"
PROBE_OK="https://w.test/a https://w.test/b"
PLAYED=""; DOWNLOADED=""
play_season_zip "My Show" "my-slug" 1 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || _fail "a season with resolvable variants should return 0, got $rc"
# resolve_stream_url yields a .zip URL, so it must download rather than stream
[ -n "$DOWNLOADED" ] || _fail "a .zip archive was streamed instead of downloaded"
[ -z "$PLAYED" ] || _fail "a .zip archive was both downloaded and played"
case "$DOWNLOADED" in
    *season-1/*) ;;
    *) _fail "download path is missing the season folder: $DOWNLOADED" ;;
esac

# --- ordering: -q 1080p must try the 1080p variant first ---------------------
quality=1080p
PLAYED=""; DOWNLOADED=""
play_season_zip "My Show" "my-slug" 1 >/dev/null 2>&1
# the download name carries the label, and the label carries the quality
case "$DOWNLOADED" in
    *1080p*) : ;;
    *) _fail "-q 1080p did not prefer the 1080p variant: $DOWNLOADED" ;;
esac

# --- stale-URL fallback: if the preferred candidate is dead, use the sibling --
# shellcheck disable=SC2034  # read by the sourced play_season_zip
quality=1080p
PROBE_OK="https://w.test/a"      # only the 480p variant is live
PLAYED=""; DOWNLOADED=""
play_season_zip "My Show" "my-slug" 1 >/dev/null 2>&1
[ $? -eq 0 ] || _fail "should fall back to a live sibling"
case "$DOWNLOADED" in
    *480p*) : ;;                 # fell through to the only live variant
    *) _fail "did not fall back to the live sibling: $DOWNLOADED" ;;
esac

# --- no live candidate at all -> 1 ------------------------------------------
PROBE_OK=""
play_season_zip "My Show" "my-slug" 1 >/dev/null 2>&1
[ $? -eq 1 ] || _fail "no resolvable candidate should return 1"

rm -rf "$download_dir" "$histfile" "$tmpfile2" "$tmpfile3"
echo "PASS (9 checks)"
