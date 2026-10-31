#!/bin/sh
# Self-check for scripts/verify-channels.sh: every channel is read correctly.
# Network is stubbed: a fake curl on PATH answers from fixtures.
# Usage: sh tests/verify_channels.sh

. "$(dirname "$0")/lib.sh"

SRC="$(cd "$(dirname "$0")/.." && pwd)/scripts/verify-channels.sh"
[ -f "$SRC" ] || { echo "verify-channels.sh missing" >&2; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-channels.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/curl" <<'STUB'
#!/bin/sh
# -w '%{http_code}' -> all fixture URLs answer 200
for a; do
    case "$a" in *http_code*) printf 200; exit 0 ;; esac
done
for a; do
    case "$a" in *://*) ;; *) continue ;; esac
    case "$a" in
        *registry.npmjs.org*) printf '{"version":"%s"}' "$FIX_VER" ;;
        *api.github.com*)     exit 22 ;;
        *aur.archlinux.org*)  printf '{"Version":"%s-2"}\n' "$FIX_VER" ;;
        *homebrew-vicine-cli*) printf '  url "https://x/refs/tags/v%s.tar.gz"\n' "$FIX_VER" ;;
        *bucket/vicine.json*) printf '{"version": "%s"}\n' "${FIX_STALE:-$FIX_VER}" ;;
        *flake.nix*)          printf '  version = "%s";\n' "$FIX_VER" ;;
        *)                    exit 22 ;;
    esac
    exit 0
done
exit 22
STUB
chmod +x "$tmp/bin/curl"

# the github release URL is an API call, and only the status code is read —
# the stub answers 200 for the -w probe above, so the body fetch is never used

run() { # $1 = version in every channel fixture; the script is invoked with 1.7.4
    PATH="$tmp/bin:$PATH" FIX_VER="$1" sh "$SRC" 1.7.4 >"$tmp/out" 2>&1
    echo "$?"
}

# 1. everything current: exit 0, six OK lines (npm, release, aur, tap, scoop, nix)
rc="$(run 1.7.4)"
[ "$rc" = 0 ] || _fail "all-good run exited $rc: $(cat "$tmp/out")"
[ "$(grep -c '^OK' "$tmp/out" | tr -d ' ')" = 6 ] \
    || _fail "expected 6 OK lines: $(cat "$tmp/out")"
grep -q 'all channels serve v1.7.4' "$tmp/out" || _fail "no all-good summary: $(cat "$tmp/out")"

# 2. one channel stale: exit 1, that channel named, the others untouched
PATH="$tmp/bin:$PATH" FIX_VER=1.7.4 FIX_STALE=1.7.3 sh "$SRC" 1.7.4 >"$tmp/stale" 2>&1
rc="$(PATH="$tmp/bin:$PATH" FIX_VER=1.7.4 FIX_STALE=1.7.3 sh "$SRC" 1.7.4 >/dev/null 2>&1; echo $?)"
[ "$rc" = 1 ] || _fail "stale channel exited $rc, want 1: $(cat "$tmp/stale")"
[ "$(grep -c '^FAIL  ' "$tmp/stale" | tr -d ' ')" = 1 ] \
    || _fail "stale run should report exactly one FAIL: $(cat "$tmp/stale")"
grep -q '^FAIL  scoop bucket' "$tmp/stale" \
    || _fail "scoop staleness not reported: $(cat "$tmp/stale")"
grep -q '^OK    npm' "$tmp/stale" \
    || _fail "healthy channels must stay OK when one lags: $(cat "$tmp/stale")"

echo "PASS (5 checks)"
