# Changelog

All notable changes to **vicine** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Whole-season ZIP entries (`season_zip`): when a selected season has no
  per-episode data, vicine picks the quality variant, resolves the archive
  URL and downloads it (mpv can't stream zip containers). Verified live on
  the "Dark Netflix" entry.

### Fixed

- Downloads fail loudly on HTTP errors (curl now uses `-f`, so a 403/404
  error page is no longer saved and reported as success), and interrupted
  downloads can't masquerade as complete files: everything stages to
  `<name>.part` and only an atomic rename publishes the final file. yt-dlp's
  own staging is kept for resuming large archives (a 5.5 GiB season zip
  interrupted at 2% previously left a "complete-looking" partial).
- Whole-season ZIP downloads probe the resolved URL (1-byte range request),
  re-resolve up to 3 times, and fall back to the season's other quality
  variant (different workers URL, independent cache): a stale, expired signed
  URL on one variant (e.g. `Dark.S03.720p.zip`) no longer blocks the season —
  the sibling variant or a fresh resolution is tried first.

## [1.4.1] - 2026-09-20

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
- `--exit-after-play` now does what it promises: plays in the foreground,
  skips the control menu, and exits with the player's exit code. Exit codes
  in general are no longer flattened to 0 by the EXIT trap (previously
  `die`, Ctrl-C, and player exit codes all surfaced as 0).
- Interactive search prompts exit cleanly on EOF instead of busy-looping at
  100% CPU (`vicine < /dev/null` no longer hangs).
- Series player title: `get_episode_name` now shows only the played episode
  instead of dumping the whole season into the title bar.
- `vicine -U` replaces the script atomically (temp file + mv) and reports a
  clear failure when the target isn't writable, instead of silently
  succeeding.
- `--uninstall` reports an error if the file can't be removed.
- `-D` wins over `-i` regardless of flag order (except `-D -A`, which stays
  on the anime download-all path).
- Result and watch-history menus are now 1-based and unpadded (previously
  "00", "01"…); series episode numbers are normalized, so `-e 3` matches
  "Episode 03" if the API ever pads.
- `-q` is case-insensitive and `4k`/`4K` normalize to `2160p`.
- The mpv debug log moved to a per-run temp file that's cleaned up; no more
  shared/world-writable `/tmp/VICINE.mpv.log`.
- `-p iina` fails loudly when `iina-cli` isn't available instead of launching
  a silent "command not found".
- Anime quality labels fall back to the variant path when the master playlist
  omits `RESOLUTION`.
- Anime: `-D -A` download-all is no longer short-circuited by the info-only
  gate that `-D` sets internally (regression from the `-i` fix).
- `select_item` treats invalid/empty API JSON as "no results" instead of
  tripping an integer-comparison error.
- Watch history dedup uses a fixed-string match — slugs containing `[` or
  other regex characters no longer break the `grep` pattern.
- Help text lists `2160p` in the quality choices alongside `4K`.

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