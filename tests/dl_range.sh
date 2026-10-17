#!/bin/sh
# Self-check for episode_loop()'s -d/--download path: a picked multi-select or
# `-e N-M` range must download every covered episode, not stop after the first
# one (the download branch used to `return` before the range auto-advance ran).
#
# The bug: `vicine -d -e 3-5 "show"` (or multi-picking episodes for a plain
# `-d`) downloaded S1E03 and returned — episodes 4..5 were silently skipped
# with no warning, exit code 0.
#
# Player + network are stubbed; the play_url stub echoes the episode number
# it was asked to play, so the assertion is on which numbers actually ran.
# Usage: sh tests/dl_range.sh

VICINE_LIB=1 . "$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
command -v episode_loop >/dev/null 2>&1 || { echo "episode_loop missing" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

# quiet the chatter the loop prints on stdout — it would pollute the captures
info() { :; }
warn() { :; }
ok() { :; }

# Globals episode_loop reads. Sourcing with VICINE_LIB stops before the Main
# section, so the mktemp/defaults there never ran — the suite makes its own,
# exactly as the functions expect them to look. Each pin: the variable is
# only read by the sourced library, which shellcheck cannot see.
# shellcheck disable=SC2034  # read by the sourced episode_loop / play branch
player_function="download"
# shellcheck disable=SC2034  # read by the sourced episode_loop...
info_only=0
# shellcheck disable=SC2034  # ...via prompt_action's -D check
download_all_mode=0
# shellcheck disable=SC2034  # ...and play_url's exit-after branch
exit_after_play=0
histfile="$(mktemp "${TMPDIR:-/tmp}/DLRANGE.XXXXXX")"
_playlog="$(mktemp "${TMPDIR:-/tmp}/DLRANGE2.XXXXXX")"
# rows "ep\turl\tqual\tsize" like parse_episodes prints. Non-contiguous on
# purpose: episode 2 does not exist (hicine specials/absolute numbering).
_ep_list='1	u1	1080p	sz
3	u3	1080p	sz
4	u4	1080p	sz
5	u5	1080p	sz'

resolve_stream_url() { printf '%s' "$1"; }
get_episode_url() { printf '%s' "$_ep_list" | awk -F'\t' -v n="$1" '$1==n{print $2; exit}'; }
get_episode_name() { printf 'Episode %s' "$1"; }
# echo the episode number from the player title ("T - Episode 3"); rc 0 = saved
play_url() { echo "${2##*Episode }" >> "$_playlog"; return "${PLAY_RC:-0}"; }
update_history() { printf '%s\t%s\n' "$1" "$5" >> "$histfile"; }

run() { # $1 = start ep, $2 = range end ('' = none) -> eps that "downloaded"
    : > "$_playlog"; : > "$histfile"
    _range_end="$2"; _cur_ep="$1"
    episode_loop "T" "slug" 1
    tr '\n' ' ' < "$_playlog" | sed 's/ *$//'
}

got="$(run 3 5)"
[ "$got" = "3 4 5" ] || _fail "range 3-5 should download 3 4 5: got [$got]"
# one history row per downloaded episode on the successful path
[ "$(awk -F'\t' '$1=="slug"' "$histfile" | wc -l | tr -d ' ')" = "3" ] \
    || _fail "history should hold 3 rows after a 3-5 download"

# range end past the last episode stops cleanly at the gap
got="$(run 3 999)"
[ "$got" = "3 4 5" ] || _fail "no overshoot past the last episode: got [$got]"

# a failing download does not abort the range (mirrors the -D bulk flow)
PLAY_RC=1
got="$(run 3 5)"
[ "$got" = "3 4 5" ] || _fail "failed episodes must not abort the range: got [$got]"
PLAY_RC=0

# single pick (no range) downloads exactly one
got="$(run 3 '')"
[ "$got" = "3" ] || _fail "no-range pick downloads exactly one: got [$got]"

echo "PASS (4 checks)"
