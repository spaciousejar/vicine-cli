#!/bin/sh
# Self-check: download runs report failure through the exit code. The
# download_all contract (rc 1 with "N episode(s) failed", covered by
# dl_all.sh) used to die at three places between it and the process exit:
# cmd_search's bare `return 0`, the `-U` fallback `exit 0`, and the main
# tail's unconditional `exit 0` — so every -d/-D run exited 0, and a script
# or cron line could not tell a failed batch from success.
# Usage: sh tests/exit_codes.sh

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

echo "PASS (4 checks)"
