#!/bin/sh
# Self-check: download runs report failure through the exit code. The
# download_all contract (rc 1 with "N episode(s) failed", covered by
# dl_all.sh) used to die at three places between it and the process exit:
# cmd_search's bare `return 0`, the `-U` fallback `exit 0`, and the main
# tail's unconditional `exit 0` — so every -d/-D run exited 0, and a script
# or cron line could not tell a failed batch from success.
# Usage: sh tests/exit_codes.sh
# shellcheck disable=SC2034  # player_function is read by the sourced play_url

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"

# 0. cmd_search hands the play/download result of the picked item to the
#    caller instead of flattening it
grep -q 'if \[ "\$info_only" -eq 1 \]; then show_info; else prompt_action; fi' "$SCRIPT" \
    || _fail "cmd_search discards the play/download status again"

# 1. the provider-chain rc is kept: its exit is the download-all result when
#    anime fallback does the whole run; the warn only adds a message, it
#    does not change the code
grep -q 'provider_chain "\$_query" "no results" || _pc_rc=\$?' "$SCRIPT" \
    || _fail "cmd_search no longer records the fallback provider's exit status"

# 2. the -D -A fallback entry point exits with that rc
grep -q '\[ "\$_backup_used" = "1" \] && exit "\${_pc_rc:-0}"' "$SCRIPT" \
    || _fail "the anime fallback download-all exit is flattened to 0 again"

# 3. the main tail: download modes exit with their status; plain play keeps 0
grep -q '\[ "\$player_function" = "download" \] || \[ "\$download_all_mode" = 1 \]' "$SCRIPT" \
    || _fail "the main exit no longer distinguishes download modes from play"

# 4. play_url must hand back the downloader's status. The case had no tail
#    return, so the `_pl_rc=$?` assignment (always 0) was the result: a failed
#    -d exited 0 and the callers' `_rc -eq 0` guards wrote a false history row.
load_vicine
do_download() { return 42; }
player_function="download"
play_url "https://example.com/video.mp4" "Test" ""
_pl_rc_seen=$?
[ "$_pl_rc_seen" -eq 42 ] || _fail "play_url download rc=$_pl_rc_seen (want 42)"

# 5. the README exit contract must match the code: no stale "always exit 0"
#    claim, and the --exit-after-play exception is stated.
_readme="$(dirname "$0")/../README.md"
! grep -q 'interactive sessions always' "$_readme" \
    || _fail "README still promises interactive sessions always exit 0"
grep -q 'That flag returns the player exit code.' "$_readme" \
    || _fail "README omits the --exit-after-play exit status"

# 6. the movie -D branch must report a failed download. The warn branch had
#    no return, so the function returned warn's 0 and a failed movie -D
#    exited 0 (the series branch returns 1).
load_vicine
tmpfile2="$(mktemp "${TMPDIR:-/tmp}/vicine-movie.XXXXXX")"
printf '%s' '{"title":"Film","contentType":"movie","url_slug":"film","links":"https://cdn.example/film.mkv, 1080p, 2GB"}' > "$tmpfile2"
download_dir="$(dirname "$tmpfile2")/dl"
movie_playable() { printf "https://cdn.example/film.mkv\n"; }
do_download() { return 42; }
warn() { :; }
update_history() { :; }
download_all_item
_movie_rc=$?
rm -f "$tmpfile2"
[ "$_movie_rc" -ne 0 ] || _fail "movie -D download failure exited 0"

echo "PASS (7 checks)"
