#!/bin/sh
# vicine installer
# usage:
#   ./install.sh                     -> install to ~/.local/bin
#   sudo ./install.sh /usr/local/bin -> install system-wide
# one-liner: curl -fsSL https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/install.sh | sh

set -e

target="${1:-$HOME/.local/bin}"
url="https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/vicine"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

mkdir -p "$target"
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$url" -o "$tmpfile"
sh -n "$tmpfile" || { echo "downloaded script failed syntax check" >&2; exit 1; }
install -m 755 "$tmpfile" "$target/vicine"

echo "Installed vicine to $target/vicine"
case ":$PATH:" in
    *":$target:"*) ;;
    *) echo "Add $target to your PATH, e.g. in ~/.bashrc: export PATH=\"$target:\$PATH\"" ;;
esac