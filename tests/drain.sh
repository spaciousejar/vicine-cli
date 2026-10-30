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

echo "PASS (3 checks)"
