#!/bin/sh
# Shared preamble for the tests. Each test stays runnable on its own:
#
#   . "$(dirname "$0")/lib.sh"
#   load_vicine
#   need sanitize
#
# _fail is the one way a self-check reports: a message and exit 1.

_fail() { echo "FAIL: $1" >&2; exit 1; }

load_vicine() { # source the real script as a library, never a copy
    # shellcheck source=/dev/null
    VICINE_LIB=1 . "$(dirname "$0")/../vicine"
}

need() { # function names that must exist after load_vicine
    for _fn; do
        command -v "$_fn" >/dev/null 2>&1 || _fail "$_fn missing from vicine"
    done
}
