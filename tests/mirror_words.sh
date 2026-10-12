#!/bin/sh
# Self-check for mirror_words_regex() in vicine — the ALL-words regex used as
# the sitemap fallback when the joined-slug search misses.
#
# The regression: the loop built the pattern with "$(_vs_w)", a COMMAND
# substitution that ran each word as a program instead of appending it, so the
# pattern came out empty and multi-word queries never reached the fallback.
# Usage: sh tests/mirror_words.sh

VICINE_LIB=1 . "$(dirname "$0")/../vicine"
command -v mirror_words_regex >/dev/null 2>&1 || { echo "mirror_words_regex missing from vicine" >&2; exit 1; }

_fail() { echo "FAIL: $1" >&2; exit 1; }

_get() { mirror_words_regex "$1"; }

[ "$(_get 'kgf chapter 2')" = 'kgf.*chapter.*2' ] \
    || _fail "multi-word: got '$(_get 'kgf chapter 2')'"
[ "$(_get 'desolation of smaug')" = 'desolation.*smaug' ] \
    || _fail "stopword drop: got '$(_get 'desolation of smaug')'"
[ "$(_get 'the a of')" = '' ] || _fail "all-stopword query should be empty"
[ "$(_get '')" = '' ] || _fail "empty query should be empty"

# the pattern must actually match a hyphenated slug (what the fallback greps)
printf '%s\n' 'https://vegamovies.gallery/download-kgf-chapter-2-2025/' \
    | grep -qiE "$(_get 'kgf chapter 2')" \
    || _fail "pattern did not match a hyphenated slug"

# user text goes into grep -E, so ERE metacharacters must be escaped: an
# unbalanced "(" made grep error out and the caller read that as "no results"
[ "$(_get 'a(b')" = 'a\(b' ] || _fail "metachar not escaped: got '$(_get 'a(b')'"
printf '%s\n' 'https://vegamovies.gallery/a(b-season-1/' \
    | grep -qiE "$(_get 'a(b')" \
    || _fail "escaped pattern did not match a literal slug"

echo "PASS (7 checks)"
