#!/bin/sh
# Self-check for the series-selection helpers in vicine.
#
# prompt_action() is the largest function in the script (~230 lines) and had no
# coverage at all until the VICINE_LIB sourcing hook let this suite call the
# real implementations instead of testing sed-extracted copies.
# Usage: sh tests/series_select.sh

SCRIPT="$(dirname "$0")/../vicine"
# shellcheck source=/dev/null
VICINE_LIB=1 . "$SCRIPT"

_fail() { echo "FAIL: $1" >&2; exit 1; }

# A series/episode count, the "how many did they ask for" narrowing used by
# both -D flows and their confirm counts, and the episode-number↔count split
# that episode_loop depends on.
command -v eps_by_request >/dev/null 2>&1 || _fail "eps_by_request missing from vicine"

LINES='1	a	480p
2	b	720p
10	c	1080p
11	d	1080p
20	e	1080p'

got() { eps_by_request "$LINES" "$1" | cut -f1 | tr '\n' ' ' | sed 's/ $//'; }

# a non-contiguous, non-1-based season — the case that made the old
# count-vs-number confusion visible
[ "$(got '')"    = "1 2 10 11 20" ] || _fail "all -> got: $(got '')"
[ "$(got 2)"     = "2" ]           || _fail "-e 2 -> got: $(got 2)"
[ "$(got 10)"    = "10" ]          || _fail "-e 10 -> got: $(got 10)"
[ "$(got 99)"    = "" ]            || _fail "-e 99 (absent) -> got: $(got 99)"
[ "$(got -1)"    = "20" ]          || _fail "-e -1 (last) -> got: $(got -1)"
[ "$(got 10-11)" = "10 11" ]       || _fail "-e 10-11 -> got: $(got 10-11)"
[ "$(got 10--1)" = "10 11 20" ]    || _fail "-e 10--1 (end=-1) -> got: $(got 10--1)"
# a range whose end sits in a gap must return what exists, not stop early
[ "$(got 2-20)"  = "2 10 11 20" ]  || _fail "-e 2-20 (gapped) -> got: $(got 2-20)"

# the last-number/count split episode_loop relies on
ep_list='10	U10	1080p	1GB
11	U11	1080p	1GB
20	U20	1080p	1GB'
last="$(printf '%s\n' "$ep_list" | tail -1 | cut -f1)"
count="$(printf '%s\n' "$ep_list" | wc -l | tr -d ' ')"
[ "$last" = "20" ]  || _fail "last episode number should be 20, got $last"
[ "$count" = "3" ]  || _fail "episode count should be 3, got $count"
# a "next" gate comparing number against count would hide the last episode
[ "$last" -gt "$count" ] || _fail "number/count are equal; the regression this guards is untestable here"

# sanitize is what keeps a hostile title out of the filesystem
[ "$(sanitize '../../etc/passwd')" = "....etcpasswd" ] || _fail "sanitize let a separator through"
[ "$(sanitize '..')" = ".." ] || _fail "sanitize now strips '.', which changes the traversal guard's input"

# A range (-e N-M, or the multi-select min/max) must advance to the next
# episode that EXISTS, not to +1: hicine seasons are not always 1..N, and +1
# landed on a missing number, get_episode_url came back empty and the loop
# stopped mid-range without saying so. Inline in episode_loop, so: on source.
grep -qF 'awk -v n="$_cur_ep" '"'"'$1>n{print $1; exit}'"'"'' "$SCRIPT" \
    || _fail "episode_loop no longer walks to the next existing episode"
grep -qF '_cur_ep=$(( _cur_ep + 1 ))' "$SCRIPT" \
    && _fail "episode_loop advances with +1 again, which stops a gapped season early"

# -e N-M's endpoint check: each row is "ep\turl\tqual\tsize", and grep -qx
# anchors the WHOLE line — a bare endpoint number could never match, so every
# valid series range died with "Episode N not found." The check has to
# narrow to the number column first.
grep -qF '| cut -f1 | grep -qx "$_start"' "$SCRIPT" \
    || _fail "the -e N-M endpoint check lost its cut -f1 narrow"
grep -qF 'printf "%s\n" "$_ep_list" | grep -qx "$_start"' "$SCRIPT" \
    && _fail "a range endpoint of -e N-M is checked against whole rows again — a tab row can never match"
grep -qF 'Invalid episode range' "$SCRIPT" \
    || _fail "a reversed range (-e 3-2) is no longer rejected"

# and the checker pattern accepts valid endpoints of a gapped, tab-separated list
EP=$(printf '1\ta\t480p\n3\tb\t720p\n5\tc\t1080p')
_start=$(printf '%s' '3-5' | grep -oE '^(-1|[0-9]+)' | head -1)
_end=$(printf '%s' '3-5' | grep -oE '(-1|[0-9]+)$' | tail -1)
printf '%s\n' "$EP" | cut -f1 | grep -qx "$_start" \
    || _fail "checker pattern rejected a valid range endpoint ($_start)"
printf '%s\n' "$EP" | cut -f1 | grep -qx "$_end" \
    || _fail "checker pattern rejected a valid range endpoint ($_end)"

# season_count reads the item in ONE jq call now; a 20-call scan per check
# made every -D start pay 20+ processes
grep -qF 'select(.key | test("^season_[0-9]+$"))' "$SCRIPT" \
    || _fail "season_fields is gone; season_count went back to the 20-call scan"

echo "PASS (22 checks)"
