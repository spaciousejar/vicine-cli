#!/bin/sh
# Self-check for picker() — the non-interactive selection path.
#
# A piped or cron run has no TTY, so the script defaults --select-nth to 0
# (vicine's own auto-pick). The pickers that did not consult it called the
# menu anyway: fzf failed with "inappropriate ioctl for device", the empty
# result read as "user cancelled", and the run exited 0 having played
# nothing. That is the worst failure mode for a scripted -D.
#
# Usage: sh tests/picker.sh

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"
load_vicine

need picker

# picker() assigns this on success; initialised so the first failure print can
# never reference an unset variable
_pick=""

LIST='1  alpha
2  beta
3  gamma'

# -n 0 -> the first row, no menu involved
select_nth=0
picker "Pick: " <<EOF
$LIST
EOF
[ "$_pick" = "1  alpha" ] || _fail "-n 0 should pick row 1, got '$_pick'"

# -n 2 -> the third row (the value is the row index, not the display row)
select_nth=2
picker "Pick: " <<EOF
$LIST
EOF
[ "$_pick" = "3  gamma" ] || _fail "-n 2 should pick row 3, got '$_pick'"

# -n out of range -> must not pick; it dies, so check it reaches the guard by
# running it in a subshell and requiring a non-zero status
# consumed by picker() inside the subshell below
# shellcheck disable=SC2034
select_nth=9
( picker "Pick: " <<EOF
$LIST
EOF
) >/dev/null 2>&1
# capture the subshell's status first: a $? read inside the _fail message
# would report the [ ] test's status instead (SC2319)
_subrc=$?
[ "$_subrc" = "1" ] || _fail "-n out of range should exit 1, got $_subrc"

# every interactive picker must route through picker(), or the -n path is
# dead again for that flow. menu() left in a picker means it ignores -n.
for site in 'picker "Episodes (Season' 'picker "Select episode: "'; do
    grep -qF "$site" "$SCRIPT" || _fail "no call site found for: $site"
done
# and none of them may call menu() directly any more
grep -qF 'menu "Episodes (Season' "$SCRIPT" \
    && _fail "the episode picker calls menu() directly again, ignoring -n"

echo "PASS (5 checks)"
