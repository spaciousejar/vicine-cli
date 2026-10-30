#!/bin/sh
# shellcheck disable=SC2034  # globals the sourced download_all_item reads
# Self-check for the series -D body (download_all_item). Two contracts:
#   - an episode whose download failed is counted and reported, and the run
#     exits non-zero instead of claiming success;
#   - the history row names the last episode that actually landed, not the
#     last one submitted (the parallel workers finish out of order).
# Usage: sh tests/dl_all.sh

. "$(dirname "$0")/lib.sh"

load_vicine
need download_all_item

info() { :; }
ok() { :; }
_dl_progress() { :; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-dlall.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# globals the body reads. Sourcing with VICINE_LIB stops before the Main
# section, so the defaults there never ran.
tmpfile2="$tmp/item.json"
tmpfile3="$tmp/menu.txt"
tmpfile5="$tmp/markers"
download_dir="$tmp/dl"
histfile="$tmp/history"
quality=best
requested_eps=""
info_only=1
download_all_mode=1
: > "$histfile"

# one season, two episodes
printf '%s' '{"title":"The Show","url_slug":"the-show","contentType":"series","season_1":"EPISODES"}' > "$tmpfile2"
parse_episodes() { printf '1\tu1\t1080p\tsz\n2\tu2\t1080p\tsz\n'; }
eps_by_request() { printf '%s\n' "$1"; }
resolve_stream_url() { printf '%s' "$1"; }
# exit 1 for whichever episode numbers are listed in $FAIL_EPS
do_download() {
    case " $FAIL_EPS " in *" ${1##*u} "*) return 1 ;; esac
    return 0
}

_history="$tmp/hist"
_warn="$tmp/warn"
update_history() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$_history"; }
warn() { printf '%s\n' "$*" >> "$_warn"; }

# "$1 = dl_jobs" -> "rc|markers|history|warnings"
run() {
    : > "$_history"; : > "$_warn"
    dl_jobs="$1"
    ( download_all_item ) </dev/null >/dev/null 2>&1
    _rc=$?
    printf '%s|%s|%s|%s' "$_rc" \
        "$(tr '\n' ' ' < "$tmpfile5" | sed 's/ *$//')" \
        "$(cat "$_history" 2>/dev/null)" \
        "$(tr '\n' ' ' < "$_warn" | sed 's/ *$//')"
}

# 1. serial: episode 2 fails. History must stay on episode 1, and the run
#    must fail loudly.
FAIL_EPS=2
out="$(run 1)"
[ "$out" = "1|1 1|the-show	The Show	series	1	1|1 episode(s) failed." ] \
    || _fail "serial failure: got [$out]"

# 2. parallel: same failure through the workers, where drain_jobs does the
#    counting. Workers can finish in any order; the marker file decides.
out="$(run 2)"
[ "$out" = "1|1 1|the-show	The Show	series	1	1|1 episode(s) failed." ] \
    || _fail "parallel failure: got [$out]"

# 3. parallel, the LATER episode fails: history must name episode 1 even if
#    episode 1's worker wrote its marker first.
FAIL_EPS=2
out="$(run 2)"
[ "$out" = "1|1 1|the-show	The Show	series	1	1|1 episode(s) failed." ] \
    || _fail "parallel failure naming: got [$out]"

# 4. parallel, only the FIRST episode fails: history names episode 2.
FAIL_EPS=1
out="$(run 2)"
[ "$out" = "1|1 2|the-show	The Show	series	1	2|1 episode(s) failed." ] \
    || _fail "parallel success marker: got [$out]"

# 5. nothing fails: exit 0, no warning, history on the last episode.
FAIL_EPS=""
out="$(run 2)"
[ "$out" = "0|1 1 1 2|the-show	The Show	series	1	2|" ] \
    || _fail "clean parallel run: got [$out]"

echo "PASS (5 checks)"
