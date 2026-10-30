#!/bin/sh
# Self-check for scripts/verify-channels.sh: every channel is read correctly,
# and the PPA check reads the binary index (not binary-all, which 404s) with
# the Debian revision stripped. A published source is not enough — 1.7.4 had
# a source on noble while apt still served 1.7.3.
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
        *bucket/vicine.json*) printf '{"version": "%s"}\n' "$FIX_VER" ;;
        *flake.nix*)          printf '  version = "%s";\n' "$FIX_VER" ;;
        *Packages.gz*)        gzip -c "$FIX_PKG" ;;
        *)                    exit 22 ;;
    esac
    exit 0
done
exit 22
STUB
chmod +x "$tmp/bin/curl"

# the github release URL is an API call, and only the status code is read —
# the stub answers 200 for the -w probe above, so the body fetch is never used

pkg="$tmp/Packages"
printf 'Package: vicine\nVersion: 1.7.4-1\nArchitecture: amd64\n' > "$pkg"

run() { # $1 = version in every channel, $2 = version in the PPA index
    printf 'Package: vicine\nVersion: %s\nArchitecture: amd64\n' "$2" > "$pkg"
    PATH="$tmp/bin:$PATH" FIX_VER="$1" FIX_PKG="$pkg" \
        sh "$SRC" 1.7.4 >"$tmp/out" 2>&1
    echo "$?"
}

# 1. everything current: exit 0, one OK line per PPA series in ppa.yml
rc="$(run 1.7.4 1.7.4-1)"
[ "$rc" = 0 ] || _fail "all-good run exited $rc: $(cat "$tmp/out")"
_n="$(grep -c '^OK    ppa ' "$tmp/out" | tr -d ' ')"
_series="$(sed -n 's/^ *PPA_SERIES: *"\(.*\)"/\1/p' "$(dirname "$SRC")/../.github/workflows/ppa.yml" | head -1)"
_want="$(printf '%s\n' $_series | wc -l | tr -d ' ')"
[ "$_n" = "$_want" ] || _fail "checked $_n PPA series, ppa.yml lists $_want: $(cat "$tmp/out")"
grep -q 'all channels serve v1.7.4' "$tmp/out" || _fail "no all-good summary: $(cat "$tmp/out")"

# 2. the PPA still serves the previous build: exit 1, and the PPA is named
rc="$(run 1.7.4 1.7.3-1)"
[ "$rc" = 1 ] || _fail "stale PPA exited $rc, want 1: $(cat "$tmp/out")"
[ "$(grep -c '^FAIL  ppa ' "$tmp/out" | tr -d ' ')" = "$_want" ] \
    || _fail "stale PPA not reported per series: $(cat "$tmp/out")"

echo "PASS (4 checks)"
