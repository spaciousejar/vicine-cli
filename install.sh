#!/bin/sh
# vicine installer
# usage:
#   ./install.sh                     -> install deps + script to ~/.local/bin
#   ./install.sh /usr/local/bin      -> install deps + script system-wide (sudo)
#   ./install.sh --no-deps           -> install script only
# one-liner: curl -fsSL https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/install.sh | sh

deps="curl jq fzf mpv yt-dlp"

# Termux (Android) reports uname -s as Linux, has no sudo, and marks itself
# only through $PREFIX=/data/data/com.termux/files/usr.
is_termux() {
    [ -n "${TERMUX_VERSION:-}" ] && return 0
    case "${PREFIX:-}" in */com.termux/*) return 0 ;; esac
    return 1
}

install_deps() {
    if is_termux; then
        # mpv is only in the x11 repo; nothing here needs root
        pkg install -y x11-repo
        pkg install -y $deps || { echo "Install the missing packages with: pkg install $deps" >&2; return 1; }
        command -v yt-dlp >/dev/null 2>&1 || pip install yt-dlp
        return 0
    fi
    case "$(uname -s)" in
        Darwin*)
            command -v brew >/dev/null 2>&1 || { echo "Homebrew required: https://brew.sh" >&2; return 1; }
            brew install $deps
            ;;
        Linux*)
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update -y && sudo apt-get install -y $deps
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm $deps
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y $deps
            elif command -v apk >/dev/null 2>&1; then
                sudo apk add $deps
            else
                echo "No supported package manager (apt/pacman/dnf/apk). Install manually: $deps" >&2
                return 1
            fi
            ;;
        *)
            echo "Unsupported OS. Install manually: $deps" >&2
            return 1
            ;;
    esac
}

need=""
# Only --no-deps or an absolute directory: a typo like --foo used to become
# the target and mkdir -p created a stray directory.
case "${1:-}" in
    ""|--no-deps|/*) ;;
    *) echo "usage: $0 [--no-deps | /absolute/install/dir]" >&2; exit 2 ;;
esac
for dep in $deps; do
    command -v "$dep" >/dev/null 2>&1 || need="$need $dep"
done
if [ -n "$need" ]; then
    case "$1" in
        --no-deps)  echo "Skipping dependencies (missing: $need)" ;;
        *)          echo "Installing dependencies:$need"; install_deps || exit 1 ;;
    esac
fi

target="${1:-${HOME}/.local/bin}"
case "$1" in
    ""|--no-deps)
        target="${HOME}/.local/bin"
        # Termux: $PREFIX/bin is already on PATH and writable without sudo
        if is_termux && [ -n "${PREFIX:-}" ]; then target="$PREFIX/bin"; fi
        ;;
esac

url="https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/vicine"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

mkdir -p "$target"
tmpfile="$(mktemp "${TMPDIR:-/tmp}/vicine-install.XXXXXX")"
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$url" -o "$tmpfile" || { echo "failed to download script" >&2; exit 1; }
[ -s "$tmpfile" ] || { echo "downloaded script is empty — aborting" >&2; exit 1; }
sh -n "$tmpfile" || { echo "downloaded script failed syntax check" >&2; exit 1; }

# Stage next to the target and rename into place. install(1) truncates the
# destination, and a vicine already playing in another terminal still has that
# file open — dash reads scripts in chunks, so a half-written file can execute.
dest="$target/vicine"
new="$(mktemp "$target/.vicine.XXXXXX")" || { echo "cannot write to $target" >&2; exit 1; }
trap 'rm -f "$tmpfile" "$new"' EXIT
cat "$tmpfile" > "$new" && chmod 755 "$new" && mv -f "$new" "$dest" \
    || { echo "failed to write $dest" >&2; exit 1; }

echo "Installed vicine to $dest"
case ":$PATH:" in
    *":$target:"*) ;;
    *) echo "Add $target to your PATH, e.g. in ~/.bashrc: export PATH=\"$target:\$PATH\"" ;;
esac