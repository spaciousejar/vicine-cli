#!/bin/sh
# Self-check for drain_jobs(), the shared waiter behind the parallel -D
# drain blocks. Pins the contract: per-PID wait (dash's bare `wait` returns
# the last job's status), and _drain_rc >= 130 when any worker was
# interrupted. Uses real child processes — subshells, no shell builtins.
# Usage: sh tests/drain.sh

. "$(dirname "$0")/lib.sh"

load_vicine

need drain_jobs

# no workers queued: drain is a no-op, rc stays 0
drain_jobs
[ "${_drain_rc:-x}" = 0 ] || _fail "empty batch reported ${_drain_rc:-unset}"

# two quiet workers: both reaped, rc 0
( sleep 0.3; exit 0 ) & _a=$!
( sleep 0.3; exit 0 ) & _b=$!
drain_jobs "$_a" "$_b"
[ "$_drain_rc" = 0 ] || _fail "quiet batch reported $_drain_rc"
kill -0 "$_a" 2>/dev/null && _fail "worker $_a not reaped"
kill -0 "$_b" 2>/dev/null && _fail "worker $_b not reaped"

# interrupted worker amid quiet ones: 130 survives the wait loop
( exit 130 ) & _c=$!
( sleep 2; exit 0 ) & _d=$!
drain_jobs "$_c" "$_d"
[ "$_drain_rc" = 130 ] || _fail "interrupted batch reported $_drain_rc"

# --- _dl_batch: the batch wrapper both -D loops share ---
need _dl_batch
dl_jobs=2

# below threshold: no drain, counters untouched ($? — _drain_rc is left
# alone by design; in real flow a nonzero _drain_rc exits from _dl_batch
# itself before the next call, so no stale value survives between calls)
_jobs=1; _waitpids=""; _done=5; _total=10; _dl_failed=0
_dl_batch
[ "$_done" = 5 ] || _fail "partial batch advanced _done to $_done"
[ "$_jobs" = 1 ] || _fail "partial batch reset _jobs"

# batch reaches dl_jobs: drains, resets counters, counts progress
( exit 0 ) & _a=$!
( exit 0 ) & _b=$!
_waitpids="$_a $_b"; _jobs=2; _done=0; _total=2; _dl_failed=0
_dl_batch
[ "${_drain_rc:-x}" = 0 ] || _fail "full batch reported $_drain_rc"
[ "$_jobs" = 0 ] || _fail "full batch left _jobs=$_jobs"
[ -z "$_waitpids" ] || _fail "full batch kept _waitpids=$_waitpids"
[ "$_done" = 2 ] || _fail "full batch left _done=$_done"
[ "${_dl_failed:-0}" = 0 ] || _fail "full batch counted failed"

# final mode with nothing left: no-op even when _jobs was reset
_jobs=0
_dl_batch final
[ "${_drain_rc:-x}" = 0 ] || _fail "empty final drain reported $_drain_rc"

# interrupt inside the batched workers survives the wrapper: the run exits
# >= 130 (the wrapper exits the caller's shell on purpose, so exercise it
# in a subshell and assert the exit code)
( ( exit 130 ) & _a=$!
  ( sleep 2; exit 0 ) & _b=$!
  _waitpids="$_a $_b"; _jobs=2; _done=0; _total=2
  _dl_batch ) ; _irc=$?
[ "$_irc" = 130 ] || _fail "interrupted batch exited $_irc instead of 130"

echo "PASS (7 checks)"
