#!/bin/sh
# Self-check for the aria2c acceleration in do_download(): yt-dlp's built-in
# downloader fetches a direct-file URL on ONE connection, while --downloader
# aria2c splits it into 16 range requests (yt-dlp hardcodes -x16 -s16 and
# forwards the referer/cookie headers). A playlist manifest keeps the native
# downloader: on an external downloader yt-dlp runs one aria2c process per
# fragment, which is slower than the -N 16 fragment loop.
#
# Each case runs with a FULLY controlled PATH (a symlink farm of the tools
# the download path touches, plus a yt-dlp stub that captures its argv and
# stages a fake file). PATH alone decides whether do_download can see an
# aria2c: a host that ships one (GitHub runner images do) must not turn the
# no-aria2c case into a different contract.
#
# Usage: sh tests/aria2c.sh

. "$(dirname "$0")/lib.sh"

load_vicine
need do_download

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-aria.XXXXXX")"
download_dir="$(mktemp -d "${TMPDIR:-/tmp}/vicine-dl.XXXXXX")"
# shellcheck disable=SC2034  # global the sourced do_download reads
curl_exe="curl"   # dead-link probe; the URL refuses on the spot, no network needed

# one bin dir per case: identical except for the aria2c stub
make_harness() { # $1 = dir, $2 = with aria2c ("yes"/"no")
    mkdir "$1"
    # the external tools the download path can call; everything it asserts on
    # came out of do_download's real branches, not assumptions
    for _t in dirname basename mkdir sed tr cksum cut head rm mv wc curl; do
        ln -s "$(command -v "$_t")" "$1/$_t"
    done
    cat > "$1/yt-dlp" <<'YTD'
#!/bin/sh
args="$*"        # captured before the loop: the -o scan consumes the args
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then printf '\x1a\x45\xdf\xa3staged-fake' > "$2"; fi
    shift
done
printf '%s\n' "$args" > "$CAP"
exit 0
YTD
    chmod +x "$1/yt-dlp"
    if [ "$2" = yes ]; then
        printf '#!/bin/sh\nexit 0\n' > "$1/aria2c"
        chmod +x "$1/aria2c"
    fi
}

yes_bin="$tmp/with-aria2c"
no_bin="$tmp/without-aria2c"
make_harness "$yes_bin" yes
make_harness "$no_bin" no

cap_all() { # $1 = capture file; join the argv lines for substring checks
    tr '\n' ' ' < "$1"
}

# 1. aria2c installed + direct .mp4 URL -> --downloader aria2c is attached
CAP="$tmp/cap1" PATH="$yes_bin" do_download "https://127.0.0.1:9/f.mp4" "Movie Direct" ""
[ "$?" = 0 ] || _fail "direct-file download with aria2c did not succeed"
case "$(cap_all "$tmp/cap1")" in
    *'--downloader aria2c'*) ;;
    *) _fail "aria2c installed and a direct .mp4 URL: --downloader aria2c missing from the yt-dlp invocation" ;;
esac

# 2. aria2c installed + .m3u8 manifest -> stays on the native fragment downloader
CAP="$tmp/cap2" PATH="$yes_bin" do_download "https://127.0.0.1:9/f.m3u8" "Movie Stream" ""
[ "$?" = 0 ] || _fail "m3u8 download did not succeed"
[ -s "$tmp/cap2" ] || _fail "m3u8 case never ran the stub (the download could not start)"
case "$(cap_all "$tmp/cap2")" in
    *'--downloader'*) _fail "a .m3u8 manifest ran with --downloader: the external downloader runs once per fragment" ;;
    *) ;;
esac

# 3. no aria2c on a controlled PATH -> the single-connection path is unchanged
CAP="$tmp/cap3" PATH="$no_bin" do_download "https://127.0.0.1:9/f.mp4" "Movie Plain" ""
[ "$?" = 0 ] || _fail "direct-file download without aria2c did not succeed"
[ -s "$tmp/cap3" ] || _fail "no-aria2c case never ran the stub (the download could not start)"
case "$(cap_all "$tmp/cap3")" in
    *'--downloader'*) _fail "--downloader aria2c ran while no aria2c is on this PATH" ;;
    *) ;;
esac

rm -rf "$tmp" "$download_dir"
echo "PASS (3 checks)"
