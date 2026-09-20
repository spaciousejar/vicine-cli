# Changelog

All notable changes to **vicine** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Anime support now uses the HiAnime backend (`hianime.at`) instead of
  anidb.app, whose endpoints no longer resolve. Search, episode listing,
  and stream extraction were reworked against HiAnime's API; playback pulls
  the HLS stream from the ZokoAnime embed (XOR-obfuscated player config,
  decoded in-shell with no extra dependencies).
- CDN streams are referer-gated — the player/downloader now send a
  Referer header (mpv, IINA, VLC, yt-dlp, ffmpeg, curl).

### Fixed

- `-c` resume against stale history entries (written by the old provider with
  different anime ids) now warns and suggests `-C` instead of dying.
- The anime episode-list request (a ~1 MB JSON) got a longer timeout so it
  doesn't truncate on slow connections.
- IINA: the referer header is passed as `--mpv-http-header-fields=…` —
  `iina-cli` silently drops raw mpv options placed before the URL, so the
  header would never have reached mpv.
- Anime: the "any server" fallback was removed — it only ever selected
  MegaPlay embeds, which the decoder can't resolve — and variant URLs that
  are already absolute are no longer double-prefixed with the master's path.
- Anime: `-i`/`--info` is honored in the anime flow (prints title + episode
  count instead of launching the player).
- `do_download`: the yt-dlp fallback chain was rewritten — it no longer
  retries without the referer after a referer-gated failure.

### Added

- `awk`, `base64` and `od` joined the required tools for the anime provider
  (they decode the embed config); all ship with base systems / coreutils.

## [1.3.0] - 2026-09-18

### Added

- `vicine --uninstall` removes the script from disk; watch history is kept.
- `-v`/`--v` are accepted as version aliases alongside `-V`/`--version`.
- README documents installing via the AUR package (`yay -S vicine`).

### Changed

- Align the help text columns and fix the "series and anime" tagline typo.
- Switch npm publishing from GitHub Packages to npmjs.
- Automate GitHub Releases on `v*` tag push — notes are generated from the commits since the previous tag (skipped if the release already exists).
- Document the release flow and `anime` keyword in the README.

> **Version note:** releases previously numbered 1.3.3–1.4.0 were
> renumbered to 1.0.0–1.3.0. If your installed version shows one of the
> old numbers, reinstall to pick up the current scheme.

## [1.2.4] - 2026-09-18

### Fixed

- Restored the `-A`/`--anime` flag — it was swallowed as part of the query, so anime searches silently fell back to movie search and `-D` anime download-all was unreachable. Help now also documents `--dub`/`--sub`.
- `-D` no longer overrides `anime` mode — both `-A -D` and `-D -A` download every episode of an anime.
- History resume: multiple entries are now separate menu lines, so `-c` continues the entry you picked instead of always resuming the first one.
- The hicine → anime fallback is scoped to plain searches — `-i` (info) and `-D` (download-all) no longer turn an hicine outage into an anime search.
- Interactive selection restored: the result menu shows again in terminals (previously the first result was always auto-selected).
- `-q 4K` now matches `2160p` variants; the quality menus list `2160p` once instead of duplicating it as `4K`.
- A cancelled season-switch no longer errors on an empty pick.
- Titles containing `&#x27;`, `&#39;`, or `&#039;` are decoded correctly.

## [1.2.3] - 2026-09-17

- Automatic publishing on `v*` tag push.

## [1.2.2] - 2026-09-17

- Restore movie playback.
- `-D` downloads at the chosen quality instead of every quality variant.

## [1.2.1] - 2026-09-17

- Resolve stream URLs before download-all of movies, so downloads fetch the real stream (not the token page).

## [1.2.0] - 2026-09-17

- `-D`/`--download-all` downloads a whole series (all seasons) or an anime (all episodes).

## [1.1.2] - 2026-09-17

- Fix the update-check comparison.
- Fix download-all playback and selection/encoding/parsing bugs.

## [1.1.1] - 2026-09-17

- Fix the update version comparison.

## [1.1.0] - 2026-09-17

- Add the movie control menu and version bump.

## [1.0.0] - 2026-09-16

- Initial public release: search, browse trending/recent/collections, stream via mpv/iina/vlc, download via yt-dlp/ffmpeg/curl, series playback, anime via hianime.at, one-liner installer, and npm packaging.