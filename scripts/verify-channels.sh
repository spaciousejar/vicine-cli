#!/bin/sh
# Verify that a published version really landed in every distribution
# channel. The release workflows can be green while a channel holds nothing
# — the Ubuntu PPA published nothing for months behind a green workflow, and
# nothing noticed until a user tried to apt install it.
#
#   sh scripts/verify-channels.sh 1.7.2
#   sh scripts/verify-channels.sh 1.7.2 --wait 20   # retry for 20 minutes
#
# --wait exists because npm, the AUR and Launchpad publish asynchronously: a
# tag push can be minutes ahead of the artifact. Exits 1 if any channel is
# still wrong when the wait is over.

OWNER="spaciousejar"
REPO="vicine-cli"
TAP_REPO="homebrew-vicine-cli"
# Series the PPA workflow uploads to. One source: the job env in ppa.yml.
PPA_YML="$(dirname "$0")/../.github/workflows/ppa.yml"
PPA_SERIES="$(sed -n 's/^ *PPA_SERIES: *"\(.*\)"/\1/p' "$PPA_YML" 2>/dev/null | head -1)"
[ -n "$PPA_SERIES" ] || { echo "cannot read PPA_SERIES from $PPA_YML" >&2; exit 2; }

ver="${1:-}"
wait_min=0
[ $# -gt 0 ] && shift

while [ $# -gt 0 ]; do
    case "$1" in
        --wait)
            wait_min="${2:-0}"
            shift 2 || shift
            ;;
        -h|--help)
            echo "usage: $0 <version> [--wait minutes]"
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

[ -n "$ver" ] || { echo "usage: $0 <version> [--wait minutes]" >&2; exit 2; }
case "$ver" in
    v*) ver="${ver#v}" ;;
esac
case "$ver" in
    *[!0-9.]*) echo "bad version: $ver" >&2; exit 2 ;;
esac

fail=0

check() { # label, expected, actual
    if [ "$3" = "$2" ]; then
        printf 'OK    %-22s %s\n' "$1" "$3"
    else
        printf 'FAIL  %-22s want %s, got %s\n' "$1" "$2" "${3:-nothing}"
        fail=1
    fi
}

get() { # url -> body on stdout, non-zero on fetch failure
    # raw.githubusercontent.com drops requests now and then; one silent retry
    # keeps a healthy channel from being reported as the one that is behind.
    curl -fsSL --max-time 30 "$1" 2>/dev/null ||
        { sleep 2; curl -fsSL --max-time 30 "$1" 2>/dev/null; }
}

code() { # url -> http status
    curl -s -o /dev/null --max-time 30 -w '%{http_code}' "$1" 2>/dev/null
}

run_checks() {
    fail=0

    # npm
    _v="$(get "https://registry.npmjs.org/vicine/latest" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)"
    check "npm" "$ver" "$_v"

    # GitHub Release
    check "github release" "200" "$(code "https://api.github.com/repos/$OWNER/$REPO/releases/tags/v$ver")"

    # AUR (the package lives in its own git, not this repo). Read the RPC:
    # the cgit plain view can serve a cached copy of the old PKGBUILD, and
    # its "Version" carries the pkgrel (1.7.5-2).
    _v="$(get 'https://aur.archlinux.org/rpc/v5/info?arg[]=vicine' | sed -n 's/.*"Version":"\([0-9][0-9.]*\)-[0-9][0-9]*".*/\1/p')"
    check "aur" "$ver" "$_v"

    # Homebrew tap (separate repo). The formula carries no version line —
    # Homebrew derives the version from the tarball URL, so read it there.
    _f="$(get "https://raw.githubusercontent.com/$OWNER/$TAP_REPO/main/Formula/vicine.rb")"
    _v="$(printf '%s' "$_f" | sed -n 's|.*refs/tags/v\([0-9.]*\)\.tar\.gz.*|\1|p' | head -1)"
    check "homebrew tap" "$ver" "$_v"

    # Scoop bucket + Nix flake (both in this repo, published from master)
    _v="$(get "https://raw.githubusercontent.com/$OWNER/$REPO/master/bucket/vicine.json" | sed -n 's/.*"version": "\([^"]*\)".*/\1/p')"
    check "scoop bucket" "$ver" "$_v"

    _v="$(get "https://raw.githubusercontent.com/$OWNER/$REPO/master/flake.nix" | sed -n 's/^ *version = "\([^"]*\)".*/\1/p')"
    check "nix flake" "$ver" "$_v"

    # Ubuntu PPA: the series has to exist AND serve this version. Read the
    # binary index, not binary-all (404 on Launchpad) and not the raw
    # version (it carries a -1 Debian revision). A published source is not
    # enough: 1.7.4 published as a source while apt still served 1.7.3.
    for _series in $PPA_SERIES; do
        _base="https://ppa.launchpadcontent.net/$OWNER/vicine/ubuntu/dists/$_series"
        _c="$(code "$_base/InRelease")"
        if [ "$_c" != "200" ]; then
            printf 'FAIL  %-22s InRelease HTTP %s\n' "ppa $_series" "$_c"
            fail=1
            continue
        fi
        _v="$(get "$_base/main/binary-amd64/Packages.gz" | gzip -dc 2>/dev/null \
            | sed -n 's/^Version: //p' | sed 's/-[0-9]*$//' | head -1)"
        check "ppa $_series" "$ver" "$_v"
    done
}

deadline=0
[ "$wait_min" -gt 0 ] 2>/dev/null && deadline=$(( $(date +%s) + wait_min * 60 ))

while :; do
    run_checks
    [ "$fail" = 0 ] && break
    if [ "$deadline" = 0 ] || [ "$(date +%s)" -ge "$deadline" ]; then
        break
    fi
    echo "--- not there yet, retrying ---"
    sleep 60
done

if [ "$fail" = 0 ]; then
    echo "all channels serve v$ver"
    exit 0
fi
echo "some channels do not serve v$ver yet" >&2
exit 1
