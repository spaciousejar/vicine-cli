# Changelog

All notable changes to **vicine** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-09-24

### Added

- Backup provider via `VICINE_PROVIDER=popmovie`: movies and series from
  the popmovie.online TMDB catalog, streams resolved through vidsrc.sh
  (ChaCha20-wasm decryption via node + per-host JWT stamping; playback
  pipes the stamped playlist through yt-dlp, no seeking). Use when hicine
  is down.

### Fixed

- `-D`/anime downloads fail fast on provider-side dead links: a dead signed
  URL (HTTP 403/404/410 from the CDN bucket) is now detected with a 1-byte
  probe before the full yt-dlp→ffmpeg→curl chain, printing one clear message
  per episode instead of a wall of errors.
- The anime `-A -D` download flow now saves episodes as `S1ENN.mp4` (matching
  the series `-D` naming) instead of `EpNN.mp4`, so `-A -D` on a partly
  downloaded title skips existing files and fetches only the missing episodes.
- Anime audio defaults to English dub; `--sub` (or
  `VICINE_ANIME_MODE=sub`) restores subtitled Japanese.
- `-D`/search now falls back automatically when hicine fails — popmovie
  (TMDB/vidsrc backup) first, then the hianime anime provider — so no
  `-A`/`VICINE_PROVIDER` flag needs to be typed for titles hicine lacks.
- `-D` on a movie whose hicine links are dead retries the same title via the
  popmovie backup instead of giving up.
- Parallel bulk downloads no longer print per-job progress bars (they stomped
  each other on one terminal line); single downloads keep the progress bar.
- `-D -e N` / `-e N-M` / `-e -1` now limit the downloaded episodes (it was
  silently ignored — the whole season downloaded anyway).
- Anime `-D` returns a non-zero exit code when an episode fails to download
  instead of reporting success.
- Backup-provider playback no longer breaks on titles containing apostrophes.
- `-D` on a search with no results exits cleanly instead of falling through
  to the download flow with a blank item (`integer expected` /
  `No downloadable links for ''`): the empty-search guard now checks content,
  not mere file existence.
- Movie quality selection matches the description only — a URL containing
  e.g. "720p" can no longer shadow a higher-quality line in `-q` movie
  play/download-all.
- The `-D` movie quality menu lists qualities from the descriptions, not
  the URLs.
- Anime masters with absolute variant URLs are now parsed like relative
  ones, so `-q` works there too (previously the `auto>` fallback ignored
  the chosen quality).

### Changed

- Movie `best` picks the highest-resolution link instead of the last
  listed one.
- Scoop manifest shims `vicine` through a Git-Bash wrapper (the raw POSIX
  script can't be executed directly by a scoop shim).
- Homebrew: IINA is a proper `cask` dependency again (the previous
  `[:cask, :recommended]` tag combo was invalid and broke dependency
  resolution); brew skips it when IINA is already installed.
- Scoop: manifest no longer hard-depends on `mpv` (it's in the `extras`
  bucket, not `main`), sets `extract_dir`, and the wrapper resolves the
  real Git Bash path (previously it wrote a literal `$dir` and called the
  WSL `bash` stub).

## [1.4.3] - 2026-09-21

### Added

- Contributor docs: contributing guidelines (CONTRIBUTING.md), a scraping
  hacking guide (hacking.md), a legal disclaimer (disclaimer.md), and
  GitHub issue templates (bug report / feature request).
- Packaging for more OSes, all pinned to the release by
  `.github/workflows/pkg-bump.yml`: Homebrew formula (macOS), Scoop
  manifest (Windows), and a Nix flake.
- Debian/Ubuntu packaging: `debian/` source package + a PPA upload
  workflow (`.github/workflows/ppa.yml`).
- AUR publishing is automated: publishing a GitHub Release bumps `pkgver`
  in `aur/PKGBUILD`, recomputes `sha256sums` and pushes to
  aur.archlinux.org (`.github/workflows/aur.yml`) — no manual AUR update.

## [1.4.2] - 2026-09-21

### Added

- `-D` on a movie downloads the chosen-quality file (same selection as `-d`).
- Interactive `-D`: the download picker now covers all three:
  - Series: quality menu + multi-select seasons.
  - Anime: quality menu + an episode-range prompt (e.g. `1-50`, empty = all).
  - Movies: quality menu.
  Non-TTY runs keep the old `-q`/all-seasons behavior.
- The `-D` quality selectors list only the qualities that are actually
  available for the item (union of episode/link variants), falling back to
  the standard list when they can't be determined.
- `-D` downloads run in parallel: `VICINE_DL_JOBS` (default 2) episodes
  download concurrently (a 4 × 2 s batch takes ~4 s instead of ~8 s). Both
  download loops were moved off pipeline-subshells so their `wait` and
  counters work in the current shell; quality menus share one
  `pick_quality_menu` helper and selects read their list via stdin redirection.
- Series episode URL resolution now runs inside the download workers too,
  overlapping the running downloads instead of serializing behind each
  batch's `wait` (resolution time is hidden behind the downloads).
- yt-dlp downloads run with `--no-warnings --quiet --progress`: only the
  progress bar and errors show — no more `[generic] Extracting URL / Falling
  back…` chatter in `-d` and `-D` output.

- Whole-season ZIP entries (`season_zip`): when a selected season has no
  per-episode data, vicine picks the quality variant, resolves the archive
  URL and downloads it (mpv can't stream zip containers). Verified live on
  the "Dark Netflix" entry.

### Changed

- Dead episode links are now handled honestly: URLs with an empty
  `vcloud=` token (API placeholders) fail resolution instead of passing
  through, `-D` skips them with "unavailable — skipped", and downloads are
  rejected when the fetched content is an HTML/XML page — no more 3 KB
  "mp4" files that pretend to be episodes.
- `-D` downloads are now organized into `download_dir/<Title>/season-N/`
  (series get their real seasons, anime land in `season-1` since hianime
  serves anime as one flat episode block, archives go under their season).
  Movies keep the flat layout.
- Downloads stage with a single `.part` level (yt-dlp writes to the final
  name, manages its own staging + resume; ffmpeg/curl stage through `.part`
  + atomic rename).

### Fixed

- Ctrl-C during a download now actually stops everything: an interrupted
  download tool (yt-dlp/ffmpeg/curl exit ≥ 130) no longer falls through to
  the next fallback downloader or on to the next episode — do_download
  returns the interrupt code, the `-D` loops exit with 130, "Interrupted." is
  printed, and partial files are cleaned.
- The "Already exists" fast-path now hints that the file may be a partial from
  an interrupted download (older versions wrote directly to the final name;
  a Ctrl-C at 0.5% on a 3.9 GB movie left a 21 MB "complete-looking" file
  that blocked re-downloads until deleted).
- The `-D` confirm prompt shows the number of seasons actually selected, not
  the series' total (picking one season no longer asks about all three).
- `-D -A` anime downloads send the `Referer` header like every other anime
  path does (`hls.1embed.buzz` is referer-gated) — previously the header was
  dropped and downloads could 403 on the manifest.
- Non-TTY `-D` runs no longer cancel at the confirm prompt: the y/N confirm
  is only asked on a real terminal, so piped/scripted runs keep the old
  auto-download behavior instead of silently doing nothing.
- Anime m3u8 variants without a `RESOLUTION=` line are no longer labelled
  with the previous variant's resolution (wrong `-q` match), and absolute
  variant URLs are no longer dropped from the quality list (the
  absolute-URL branch was previously unreachable). The variant parser was
  factored into `anime_variants()` and is covered by
  `tests/m3u8_variants.sh`.
- Parallel `-D` batches propagate a worker exit code ≥ 130 (interrupt)
  instead of continuing to spawn jobs.
- `-n N` out-of-range selection is rejected even when the search returns a
  single result (previously it silently played result 1).
- The one-liner installer aborts when the download fails or comes back empty
  (an empty file used to pass the syntax check and install a 0-byte
  binary).
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