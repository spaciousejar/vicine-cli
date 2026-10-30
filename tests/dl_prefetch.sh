#!/bin/sh
# Self-check for the serial -D prefetch scheduling in vicine.
#
# The bug: the prefetch of episode N+1 is backgrounded with "&" and its PID
# discarded, so nothing reaped it before episode N+1 read the result file. When
# do_download returned faster than resolve_stream_url (an "Already exists"
# hit, a 401/403 probe failure, a rejected error page) the read saw an empty
# file, reported the episode "unavailable", and cascaded for the rest of the
# season — while still exiting 0. Real trigger: re-running `vicine -D` after an
# interrupted download, the gap-fill case the docs advertise.
#
# This asserts on the real source rather than a transcription: the serial loop
# is inline in prompt_action (not an extractable function), so a copy would
# keep passing after the fix was reverted.
# Usage: sh tests/dl_prefetch.sh

. "$(dirname "$0")/lib.sh"

SCRIPT="$(dirname "$0")/../vicine"

# 1. the prefetch's PID must be captured, or nothing can ever reap it
grep -q '_prepid=\$!' "$SCRIPT" || \
    _fail "the -D prefetch still discards its PID (no '_prepid=\$!'); a fast do_download reads an empty prefetch and every remaining episode is skipped"

# 2. that PID must be waited on before the prefetch file is read
grep -q 'wait "\$_prepid"' "$SCRIPT" || \
    _fail "the -D prefetch PID is captured but never waited on"

# 3. both must sit inside the serial branch, i.e. after the prefetch is
#    backgrounded and not in the parallel one that resolves in the worker
awk '
  /_prepid=\$!/            { cap = NR }
  /wait "\$_prepid"/        { wai = NR }
  /_r="\$\(cat "\$_prefile"/ { cat = NR }
  END { exit !(cap && wai && cat && wai < cat) }
' "$SCRIPT" || \
    _fail "the -D prefetch is not reaped before '\$_r=\$(cat \$_prefile)' reads it"

echo "PASS (3 checks)"
