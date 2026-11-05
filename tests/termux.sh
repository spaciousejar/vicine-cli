#!/bin/sh
# Self-check: vicine on Termux (Android). Termux reports uname -s as Linux,
# so it looked like a desktop: the script made its temp files in /tmp, which
# does not exist there, and the player default was mpv, whose Android build
# renders nothing without termux-x11. The installer ran sudo (absent) and
# installed into ~/.local/bin (not on PATH).
# Usage: sh tests/termux.sh

. "$(dirname "$0")/lib.sh"

load_vicine
need is_termux play_url default_player

SRC="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-termux.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# --- detection: uname says Linux, only $PREFIX/$TERMUX_VERSION tell ---
TERMUX_VERSION=0.118 is_termux || _fail "TERMUX_VERSION not detected as Termux"
PREFIX=/usr is_termux && _fail "PREFIX=/usr misdetected as Termux"
(
    unset TERMUX_VERSION PREFIX
    is_termux
) && _fail "plain Linux misdetected as Termux"
( export PREFIX=/data/data/com.termux/files/usr; is_termux ) ||
    _fail "com.termux PREFIX not detected as Termux"

# --- temp files follow TMPDIR: /tmp is missing on Termux ---
grep -q 'mktemp /tmp' "$SRC/vicine" && _fail "an absolute /tmp mktemp is back in vicine"
_err="$(VICINE_LIB='' TMPDIR="$tmp/absent" sh "$SRC/vicine" -V 2>&1 >/dev/null)"
case "$_err" in
    *"$tmp/absent"*) ;;
    *) _fail "mktemp ignored TMPDIR=$tmp/absent: $_err" ;;
esac

# --- player hand-off: termux-open-url gets the bare URL, no mpv flags ---
mkdir "$tmp/bin"
cat > "$tmp/bin/termux-open-url" <<STUB
#!/bin/sh
printf '%s\n' "\$#" "\$@" > "$tmp/argv"
STUB
chmod 755 "$tmp/bin/termux-open-url"

_handoff() { # player_function/_player_pid are read by the sourced play_url
    play_url "$1" "Some Movie" "https://zokoanime.video/"
    wait "$_player_pid" 2>/dev/null
}

# shellcheck disable=SC2034  # global play_url reads
player_function="termux-open-url"
_player_pid=""
_url="https://cdn.example/movie.m3u8"
_out="$(PATH="$tmp/bin:$PATH" _handoff "$_url")"
case "$_out" in
    *Referer*) ;;
    *) _fail "no warning about the dropped Referer header: $_out" ;;
esac
[ "$(sed -n 1p "$tmp/argv")" = 1 ] || _fail "termux-open-url got $(sed -n 1p "$tmp/argv") args, want 1"
[ "$(sed -n 2p "$tmp/argv")" = "$_url" ] || _fail "termux-open-url got '$(sed -n 2p "$tmp/argv")', want $_url"

# --- default player: termux-open-url on Termux, mpv on a desktop ---
ln -s "$(command -v cut)" "$tmp/bin/cut"
mkdir "$tmp/mpvbin"
ln -s "$(command -v cut)" "$tmp/mpvbin/cut"
printf '#!/bin/sh\nexit 0\n' > "$tmp/mpvbin/mpv"
chmod 755 "$tmp/mpvbin/mpv"

# dep_ch_failover needs cut in the same stripped PATH
_pick() { ( unset VICINE_PLAYER PREFIX; TERMUX_VERSION=1 PATH="$1" default_player ); }
[ "$(_pick "$tmp/bin")" = termux-open-url ] ||
    _fail "Termux default player is '$(_pick "$tmp/bin")', want termux-open-url"
[ "$(_pick "$tmp/mpvbin")" = mpv ] ||
    _fail "Termux default with no termux-open-url is '$(_pick "$tmp/mpvbin")', want mpv"
( unset TERMUX_VERSION PREFIX; PATH="$tmp/bin" default_player ) >/dev/null &&
    _fail "desktop default player picked termux-open-url"

# --- installer: no sudo, installs into $PREFIX/bin ---
mkdir "$tmp/curlhome"
cat > "$tmp/bin/curl" <<STUB
#!/bin/sh
while [ \$# -gt 0 ]; do
    case "\$1" in -o) shift; out="\$1" ;; esac
    shift
done
printf '#!/bin/sh\\nexit 0\\n' > "\$out"
STUB
chmod 755 "$tmp/bin/curl"

_out="$(HOME="$tmp/home" TERMUX_VERSION=1 PREFIX="$tmp/prefix" \
        PATH="$tmp/bin:$PATH" sh "$SRC/install.sh" --no-deps 2>&1)"
[ -x "$tmp/prefix/bin/vicine" ] ||
    _fail "Termux install target missing: $_out"
[ -e "$tmp/home/.local/bin/vicine" ] &&
    _fail "Termux install wrote to the non-PATH ~/.local/bin"

# a non-Termux host keeps the old default
_out="$(HOME="$tmp/home2" PATH="$tmp/bin:$PATH" sh "$SRC/install.sh" --no-deps 2>&1)"
[ -x "$tmp/home2/.local/bin/vicine" ] ||
    _fail "desktop install target moved: $_out"

echo "PASS (13 checks)"
