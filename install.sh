#!/bin/sh
# vicine installer
# usage:
#   ./install.sh                     -> install deps + script to ~/.local/bin
#   ./install.sh /usr/local/bin      -> install deps + script system-wide (sudo)
#   ./install.sh --no-deps           -> install script only
# one-liner: curl -fsSL https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/install.sh | sh

deps="curl jq fzf mpv yt-dlp"

install_deps() {
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
[ "$1" = "--no-deps" ] && target="${HOME}/.local/bin"

url="https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/vicine"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

mkdir -p "$target"
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$url" -o "$tmpfile" || { echo "failed to download script" >&2; exit 1; }
[ -s "$tmpfile" ] || { echo "downloaded script is empty — aborting" >&2; exit 1; }
sh -n "$tmpfile" || { echo "downloaded script failed syntax check" >&2; exit 1; }
install -m 755 "$tmpfile" "$target/vicine"

echo "Installed vicine to $target/vicine"
case ":$PATH:" in
    *":$target:"*) ;;
    *) echo "Add $target to your PATH, e.g. in ~/.bashrc: export PATH=\"$target:\$PATH\"" ;;
esac