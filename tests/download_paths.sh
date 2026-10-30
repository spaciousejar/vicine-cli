#!/bin/sh
# Self-check for the download-path guards added in the 2026-09-28 audit:
# check_stream_url (option injection), sanitize + the _dl_dir traversal
# filter, and dl_find (container-agnostic existence check).
# Usage: sh tests/download_paths.sh
#
# The suite sources the real script (VICINE_LIB=1), so the test can never
# silently test a stale copy.

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"
load_vicine
need check_stream_url dl_find sanitize

# minimal stand-ins for the script's globals the guards touch
die() { echo "  $1"; return 1; }

# --- check_stream_url: a "--" from the provider must never reach argv ---------
# mpv --script= runs Lua, yt-dlp --exec= runs a shell command; both parse a
# leading "--" payload as an option, and the 401/403 probe skips non-http URLs.
check_stream_url "--script=/tmp/pwn.lua" >/dev/null 2>&1 && _fail "allowed mpv --script= payload"
check_stream_url "--exec=touch /tmp/pwned" >/dev/null 2>&1 && _fail "allowed yt-dlp --exec= payload"
check_stream_url "/etc/passwd" >/dev/null 2>&1 && _fail "allowed an arbitrary local file"
check_stream_url "/tmp/VICINE.somebody-elses-manifest" >/dev/null 2>&1 && _fail "allowed a local path (no provider hands one over any more)"
check_stream_url "http://cdn.test/a.m3u8" >/dev/null 2>&1 || _fail "rejected a valid http URL"
check_stream_url "https://cdn.test/a.mp4" >/dev/null 2>&1 || _fail "rejected a valid https URL"

# --- sanitize + the _dl_dir traversal filter --------------------------------
# sanitize strips "/" but keeps ".", so a ".." title survives it; the filter
# in do_download is what stops the resulting dirname escaping download_dir.
esc() { # $1 = title -> what sanitize alone leaves as the season path
    _n="$(sanitize "$1")/season-1/S1E01"
    printf '%s' "$(dirname "$_n")/$(sanitize "$(basename "$_n")").mp4"
}
[ "$(esc "Normal Movie")" = "Normal_Movie/season-1/S1E01.mp4" ] \
    || _fail "a normal title lost its season path -> $(esc "Normal Movie")"
[ "$(sanitize "../../etc/evil")" = "....etcevil" ] \
    || _fail "sanitize stopped stripping /: $(sanitize "../../etc/evil")"
# the property the traversal filter depends on
[ "$(sanitize "..")" = ".." ] \
    || _fail "sanitize now strips '.', which changes the traversal guard's input"

# --- the _dl_dir traversal filter, asserted on the real source ---------------
# sanitize strips "/" but keeps ".", so a ".." title survives it — the filter in
# do_download is what stops the resulting dirname escaping download_dir. It is
# inline, not extractable, so it is matched on the source: a transcription
# would keep passing after the filter was deleted. Order matters — the filter
# has to sit between dirname and the mkdir.
_dir_l=$(grep -n '_dl_dir="$(dirname' "$SCRIPT" | head -1 | cut -d: -f1)
_filt_l=$(grep -nF '*/../*|*/./*' "$SCRIPT" | head -1 | cut -d: -f1)
_mk_l=$(grep -nF 'mkdir -p "$(dirname "$_dl_file")"' "$SCRIPT" | head -1 | cut -d: -f1)
[ -n "$_dir_l" ] && [ -n "$_filt_l" ] && [ -n "$_mk_l" ] && \
    [ "$_dir_l" -lt "$_filt_l" ] && [ "$_filt_l" -lt "$_mk_l" ] || \
    _fail "do_download lost the _dl_dir traversal filter, or it no longer runs between dirname ($_dir_l) and mkdir ($_mk_l) — a '..' title escapes download_dir"

# --- do_download must APPLY check_stream_url, not merely define it -----------
# The 2026-10-11 audit regression: check_stream_url existed but only play_url
# called it, so -d/-D fed provider text straight to yt-dlp/ffmpeg/curl as an
# option (yt-dlp --exec= runs a shell). Assert the call sits inside
# do_download, ahead of the first external tool.
_dd_l=$(grep -nF 'do_download() {' "$SCRIPT" | head -1 | cut -d: -f1)
_guard_l=$(grep -nF 'check_stream_url "$_url"' "$SCRIPT" \
    | awk -F: -v d="$_dd_l" '$1 > d { print $1; exit }')
_ytdlp_l=$(grep -nF 'yt-dlp $_yt' "$SCRIPT" | head -1 | cut -d: -f1)
[ -n "$_dd_l" ] && [ -n "$_guard_l" ] && [ -n "$_ytdlp_l" ] && \
    [ "$_guard_l" -gt "$_dd_l" ] && [ "$_guard_l" -lt "$_ytdlp_l" ] || \
    _fail "do_download does not call check_stream_url before yt-dlp — a provider '--exec=' payload reaches the downloader"

# --- dl_find: any real container counts, staging files do not ---------------
_D=/tmp/VICINE.selfcheck.dl; rm -rf "$_D"; mkdir -p "$_D"
[ -n "$(dl_find "$_D/S1E01")" ] && _fail "dl_find invented a file in an empty dir"
: > "$_D/S1E01.part"
[ -n "$(dl_find "$_D/S1E01")" ] && _fail "dl_find treated a .part as complete"
: > "$_D/S1E01.mkv"
[ "$(dl_find "$_D/S1E01")" = "$_D/S1E01.mkv" ] || _fail "dl_find missed a .mkv completion"
[ -z "$(dl_find "$_D/S1E02")" ] && : || _fail "dl_find matched an unrelated episode"
mkdir -p "$_D/[2020] Weird"
[ -z "$(dl_find "$_D/[2020] Weird/S1E01")" ] || _fail "dl_find glob-expanded a bracket title"

rm -rf "$_D"
echo "PASS (17 checks)"
