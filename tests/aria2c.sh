#!/bin/sh
# Self-check for the aria2c acceleration in do_download(): yt-dlp's built-in
# downloader fetches a direct-file URL on ONE connection, while --downloader
# aria2c splits it into 16 range requests (yt-dlp hardcodes -x16 -s16 and
# forwards the referer/cookie headers). A playlist manifest keeps the native
# downloader: on an external downloader yt-dlp runs one aria2c process per
# fragment, which is slower than the -N 16 fragment loop.
# The stub yt-dlp captures its command line, so each branch asserts on the
# real invocation, not on grepping the source.
# Usage: sh tests/aria2c.sh

. "$(dirname "$0")/lib.sh"

load_vicine
need do_download

tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-aria.XXXXXX")"
download_dir="$(mktemp -d "${TMPDIR:-/tmp}/vicine-dl.XXXXXX")"
quality="best"
curl_exe="curl"   # dead-link probe; the URL refuses on the spot, no network needed

yes_bin="$(mktemp -d "${TMPDIR:-/tmp}/vicine-ya.XXXXXX")"   # aria2c on PATH
no_bin="$(mktemp -d "${TMPDIR:-/tmp}/vicine-na.XXXXXX")"    # aria2c absent

make_yt() { # $1 = target dir for the yt-dlp stub
    cat > "$1/yt-dlp" <<'YTD'
#!/bin/sh
args="$*"        # captured before the loop: shift consumes the argument list
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then printf '\x1a\x45\xdf\xa3staged-fake' > "$2"; fi
    shift
done
printf '%s\n' "$args" > "$CAP"
exit 0
YTD
    chmod +x "$1/yt-dlp"
}
make_yt "$yes_bin"
make_yt "$no_bin"
printf '#!/bin/sh\nexit 0\n' > "$yes_bin/aria2c"
chmod +x "$yes_bin/aria2c"

run_dl() { # $1 = bin dir on PATH, $2 = URL, $3 = title, $4 = capture; each
    # case gets its own title, or an earlier saved file makes the later ones
    # bail at "Already exists" and the stub never runs
    CAP="$4" PATH="$1:$PATH" do_download "$2" "$3" ""
    [ "$?" = 0 ] || _fail "$3: download did not succeed"
}

# 1. aria2c installed + direct .mp4 URL -> --downloader aria2c is attached
run_dl "$yes_bin" "https://127.0.0.1:9/f.mp4" "Movie Direct" "$tmp/cap1"
case "$(tr '\n' ' ' < "$tmp/cap1")" in
    *'--downloader aria2c'*) ;;
    *) _fail "aria2c installed and a direct .mp4 URL: --downloader aria2c missing from the yt-dlp invocation" ;;
esac

# 2. aria2c installed + .m3u8 manifest -> stays on the native fragment downloader
run_dl "$yes_bin" "https://127.0.0.1:9/f.m3u8" "Movie Stream" "$tmp/cap2"
[ -s "$tmp/cap2" ] || _fail "m3u8 case never re-ran the stub (an earlier case left its file behind)"
case "$(tr '\n' ' ' < "$tmp/cap2")" in
    *'--downloader'*) _fail "a .m3u8 manifest ran with --downloader: the external downloader runs once per fragment" ;;
    *) ;;
esac

# 3. no aria2c on PATH -> the single-connection path is used unchanged
run_dl "$no_bin" "https://127.0.0.1:9/f.mp4" "Movie Plain" "$tmp/cap3"
[ -s "$tmp/cap3" ] || _fail "no-aria2c case never re-ran the stub (an earlier case left its file behind)"
case "$(tr '\n' ' ' < "$tmp/cap3")" in
    *'--downloader'*) _fail "--downloader aria2c ran while aria2c is not on PATH" ;;
    *) ;;
esac

rm -rf "$tmp" "$yes_bin" "$no_bin" "$download_dir"
echo "PASS (3 checks)"
