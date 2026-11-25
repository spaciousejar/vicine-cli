#!/bin/sh
# Self-check for the /hapi browse collection filters. The site's own frontend
# filters with `type` and `industry`; sending the old collection names as
# `genre=` made every collection return the same unfiltered catalog.
# Stubbed. Usage: sh tests/hicine_browse.sh
# shellcheck disable=SC2034

. "$(dirname "$0")/lib.sh"

SRC="$(dirname "$0")/../vicine"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/vicine-browse.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# fake curl: log each /hapi URL, write an empty items payload to the -o target
cat > "$tmp/curl" <<'EOF'
#!/bin/sh
for a in "$@"; do
    case "$a" in
        https://*/hapi/*) printf '%s\n' "$a" >> "$CURL_LOG" ;;
    esac
done
for a in "$@"; do
    if [ "$want_out" = 1 ]; then printf '%s' '{"items":[]}' > "$a"; want_out=0; fi
    [ "$a" = -o ] && want_out=1
done
exit 0
EOF
chmod +x "$tmp/curl"

# non-interactive test; stub fzf so dep check passes on runners without it
cat > "$tmp/fzf" <<'EOF'
#!/bin/sh
head -n 1
EOF
chmod +x "$tmp/fzf"

check() { # $1 = collection, $2 = expected query fragment
    : > "$tmp/log"
    _err="$tmp/err.$1"
    CURL_LOG="$tmp/log" PATH="$tmp:$PATH" VICINE_MENU='' \
        sh "$SRC" -b "$1" -i -n 0 --page 1 >/dev/null 2>"$_err" || {
        _fail "collection '$1' exit $?: $(tr '\n' ' ' < "$_err") log=$(tr '\n' ' ' < "$tmp/log")"
    }
    grep -q "/hapi/browse?$2&page=1" "$tmp/log" || \
        _fail "collection '$1' requested: $(tr '\n' ' ' < "$tmp/log") err=$(tr '\n' ' ' < "$_err")"
}

check movies            "type=movie&industry=hollywood"
check hollywood_series  "type=series&industry=hollywood"
check bollywood_movies  "type=movie&industry=bollywood"
check bollywood_series  "type=series&industry=bollywood"
check anime             "type=anime"

echo "PASS (5 checks)"
