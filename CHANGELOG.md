# Changelog

All notable changes to **vicine** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.0] - 2026-10-13

### Security

- Remote provider text can no longer reach the player or downloader as a bare
  positional argument. A `--`-prefixed "URL" from the API was parsed as an
  option — `mpv --script=` executes Lua, `yt-dlp --exec=` runs a shell command
  — and the dead-link probe did not stop it because it only runs for http(s)
  URLs. Stream URLs are now checked before use, and only an http(s) URL or the
  script's own local manifest is accepted (#40).
- A hostile title can no longer escape `download_dir` by one path segment.
  `sanitize` strips `/` but keeps `.`, so a title of `..` survived it and the
  unsanitised `dirname` was then `mkdir -p`'d (#43).
- `vicine -U` refuses an update source outside
  `raw.githubusercontent.com/spaciousejar/vicine-cli`, so `VICINE_UPDATE_URL`
  can no longer be used to install arbitrary code, and stages the payload
  through `mktemp` instead of a predictable `$0.tmp.$$` (#44).
- `umask 077` before anything is created: watch history was `0644` in a `0755`
  directory, and every derived `/tmp` path was a world-readable truncating
  open on a world-visible name (#46).
- A title containing a newline or tab can no longer forge a history row whose
  season field reaches a jq program; the season read back from history is
  digits-checked (#50).
- History dedup compares slugs as strings. `awk`'s numeric compare made slug
  `005` delete the row for `5` (#48).
- `.gitignore` covers the zxc session cookie jar, `.freebuff` and
  `.playwright-mcp`; `git add -A` was publishing a `0644` cookie jar holding
  `cf_clearance` (#47).

### Fixed

- `-e N--1` (episode N to the last) dropped episode N and could pull in
  episodes *below* it. The start bound was parsed with `%` instead of `%%`, so
  `10--1` yielded `10-`, which awk compares as a string — `"2" > "10-"` is
  true, so episode 2 came back in the range. An existing test asserted the
  broken answer (`-e 4--1` → `5`) and so passed by accident (#54-era sweep).

- `prompt_action` (234 lines) now delegates the whole-season-archive path to
  a `play_season_zip` function with a 0/1 "handled / nothing to play"
  contract, taking it to 166 lines. The extracted behaviour is pinned by a new
  `tests/season_zip.sh`, including the quality-first candidate ordering and
  the stale-URL fallback that ordering exists for.

- The suites now source the real script (`VICINE_LIB=1 vicine`) instead of
  `eval`-ing functions sed-extracted from it, and a new `series_select.sh`
  covers the series/episode narrowing that `prompt_action` — the largest
  function in the file — had never exercised.

- `-D` no longer reports the rest of a season "unavailable". The next
  episode's resolve was backgrounded with its PID discarded, so a fast
  `do_download` — an "Already exists" hit, a 401/403 probe failure, a rejected
  error page — read an empty prefetch and cascaded for the whole season while
  still exiting 0. This hit re-runs of `-D` after an interrupted download,
  the gap-fill case the docs advertise (#41).
- `-D` on a series now records watch history. `_slug` was only ever assigned
  in `prompt_action`, which `-D` can never reach, so `update_history` bailed
  and the title never appeared under `-c` (#42).
- `change_season` and `change_quality` use the last episode number rather than
  the episode count for `_ep_total`, and `change_season` starts at the season's
  first episode instead of hardcoding 1 — both silently broke absolute-numbered
  or gapped seasons. Unfixed half of #28 (#49).
- `stat -c%s` replaced with `wc -c` in the yt-dlp `.part` recovery. BSD/macOS
  `stat` has no `-c`, so the test errored, the recovery never ran, and the
  finished file was deleted (#45).
- A bare subcommand word is always a command, so `-i anime naruto` uses the
  anime provider instead of searching for the literal words; `-i -D` now
  downloads as the flag-order comment claimed (#51).
- `--exit-after-play` after a whole-season ZIP play returns the player's exit
  code. `$?` referred to the `[` test, so it always exited 0 (SC2319, #39).
- ShellCheck `warning`+ is enforced in CI, plus suites for the new download
  guards and the `-D` prefetch scheduling (#39, #53).
- `-A -D` on an anime split into two cours silently skipped the whole second
  one. hianime lists the episode numbers twice under different internal ids and
  `anidb_episodes` dedups the whole row, so both survived; every destination
  was a hardcoded `season-1/S1E##`, so the second copy of each number hit
  `dl_find` and printed "Already exists". The list is now tagged with which
  run of a number each row is and that picks the season folder.
- Watch history no longer loses a row when two copies run at once. It staged
  through a fixed `$histfile.tmp`, so the second copy's `awk` truncation
  erased the first one's new row before its `mv` — measured at 1 row kept out
  of 2. Staging goes through `mktemp` now.
- A query containing a regex metacharacter no longer breaks mirror search.
  `mirror_words_regex` fed the raw word to `grep -E`, so `vicine -z "a(b"`
  printed `grep: Unmatched ( or \(` and reported "No results on the mirror
  sites". `-z HOST` matched with a pattern too, where `*` silently narrowed
  the search to one host and `vegamovies|rogmovies` dropped a host that was
  never named; both are literal compares now.
- `-e N-M` and the episode multi-select no longer stop early on a season with
  gaps. Range advance stepped to `_cur_ep + 1`, which lands on a number the
  season does not have (0-specials, absolute numbering); the lookup came back
  empty and the loop exited mid-range without a word. It walks to the next
  episode that exists, like the `next` menu item always did.
- A failed season-archive download no longer records watch history. It was the
  only download path that ignored `do_download`'s result, so `-c` offered to
  resume a file that was never written.
- `-z -D` on a mirror *season* is refused with an explanation instead of
  downloading one unlabelled episode and naming it after the whole season.
- Ctrl-C during a mirror search no longer strands its staging directory
  (~5 MB per host) in `/tmp`: `mirror_search` runs inside a `$( )` subshell the
  main EXIT trap cannot reach, so it now traps INT/TERM itself. The EXIT trap
  also covers `${tmpfile}.tmp`, which `cmd_browse` stages through.
- Two suites cover the last pure provider code: `tests/anime_plumbing.sh`
  (endpoint templates, `zoko_xor`, `anime_pick_quality`) and `tests/sanitize.sh`
  — `zoko_xor` is pinned to a known-plaintext fixture because a wrong key just
  yields an empty `_src` rather than an error (#53).
- Anime endpoint URLs are built with `${tmpl%"%s"}$value` instead of `printf`
  with the template as the format. The templates are hardcoded today, so this
  is not a live bug, but a `%` anywhere in one would become a format specifier
  the moment it gains an env override (#38).
- `install.sh` stages the new script next to the target and renames it instead
  of letting `install(1)` truncate the destination, which a `vicine` already
  playing in another terminal still has open.
- The monthly audit workflow now runs: it had no `actions/checkout`, so `gh`
  could not resolve the repository and the job failed with "not a git
  repository" on every scheduled run.
- `pkg-bump` now commits the `aur/PKGBUILD` it rewrites. The sed ran on the
  runner but the auto-commit's file list left it out, so the in-repo AUR pin
  would have gone stale and failed `release-verify` at the next release.
- The ShellCheck action is pinned to a release SHA instead of `@master`.
- `season_count` and `show_info` read every `season_N` of the selected item in
  one `jq` call instead of spawning up to twenty; the season menu, the numbered
  picker, the quality picker and the movie-URL pick are shared helpers instead
  of three near-copies each. The unreachable local-manifest branch in
  `do_download` is gone (`check_stream_url` refuses every non-http URL).
- New `tests/history.sh` covers the one file vicine writes between runs, which
  had no coverage: row write, dedup, numeric slugs, tab/newline flattening and
  the unique staging file.

### Changed

- Watch history is only recorded when the player actually succeeded (the anime
  and mirror paths; the hicine movie flow already did).
- Episode multi-select uses min/max of the picks. `fzf -m` prints in selection
  order, so picking ep 5 then ep 2 dropped the range and played only ep 5.
- The anime gap-fill scan accepts any completed container, not just `.mp4`, so
  a `.mkv` completion is no longer re-fetched on every `-D` run.
- `HUP` and `TERM` now exit 129 and 143 instead of 0.
- A collapsed dead branch in `cmd_search`'s server-1 fallback.

### Added

- `-z` / `--mirrors` goes straight to the film mirrors, skipping hicine and
  hianime; `-z HOST` narrows to one — the full host or its first label, so
  `-z vegamovies` and `-z vegamovies.gallery` both work. An unrecognised word
  is left as query text, so `vicine -z dune` still searches the mirrors for
  "dune".
- Mirror fallbacks `vegamovies.gallery` and `rogmovies.best` — same operator,
  same `nexdrive.fit` → `fastdl.zip/embed` → googleusercontent gateway chain,
  and the same dead client-side search (`?s=` returns 200 with no results in
  the HTML). Two sibling sites were measured and dropped: `gokuhd.com`
  covered none of 8 sampled titles hicine lacks, and `xprimehub.pics` is an
  adult site that would otherwise surface in anyone's fallback results.
  Discovery goes through the sitemap index, which is parsed rather than counted
  because the post-sitemap count and naming differ per host and the first is
  sometimes `post-sitemap.xml` rather than `post-sitemap1.xml`. Both hosts
  together are ~25 sitemap fetches and ~5 MB, paid only after hicine has
  missed. Gateways vary — only some carry a fastdl embed, and the embed path
  is `/embed` or `/embed.php` depending on the page — so each is tried until
  one resolves.
- Fallback order is now hicine → the film mirrors → hianime, so a general
  query exhausts the film catalogues before reaching the anime-only one. `-A`
  still goes straight to anime.

### Removed

- The popmovie provider (server-2). Its TMDB/vidsrc chain is gone along with
  `VICINE_PROVIDER=popmovie` and the dead `$tmpfile5` playlist temp. The `-D`
  retry of a failed hicine movie download goes with it; the fallback chain is
  now hicine → the film mirrors → hianime.
- The zxc (zxcstream/vidstuck) provider, its `zxc` subcommand, and the
  `$tmpfile6` DASH manifest temp.

## [1.5.2] - 2026-09-28

### Fixed

- Successful runs exit 0 instead of 1 (the final `&& exit 0` leaked 1 for
  non-download modes) (#24).
- Picking ESC exits quietly again — `$?` inside `if !` is always 0, so the
  #11 cancel path was dead code; rc is now captured before the negation
  (#27).
- `-D` no longer clobbers `-b`/`-t`/`-r`/`-c` modes; it only rewrites the
  bare-search case (#26).
- Non-Latin titles (Hindi, Japanese, ...) keep their script in filenames
  instead of collapsing to `.mp4` and false "Already exists"; degenerate
  all-hostile titles get a stable numeric name (#25).
- `VICINE_MENU` is respected on non-TTY runs (#30).
- Series play: next/previous step to existing episodes and the header uses
  the highest episode number, not the line count (#28); `-e N-M` validates
  the end of the range (#29).
- `change_quality` no longer lists `best` twice (series) and the movie
  picker lists the real variants (#31, #32).
- popmovie/pop_series episode selects re-validate the picked episode (#33).
- `hdec` decodes entities once and is applied at the picker, control menus,
  and history rows (#34).
- Dropped a dead guard in `select_item` (#35).

### Added

- `-D` series/anime downloads run one at a time by default so each episode
  shows yt-dlp's own progress bar (movies already did); parallel is opt-in
  via `VICINE_DL_JOBS`, where per-job bars are suppressed and a
  `[####------] done/total` ASCII tally is shown instead.
- The `-D` confirm is `[Y/n]`: Enter or `y` downloads, anything else cancels; empty or
  `y`/`Y` downloads.

## [1.5.1] - 2026-09-26

### Fixed

- The anime episode picker maps the display row back to the real episode
  number — non-contiguous hianime numbering (0-specials, season 2 starting
  at 13) no longer plays the wrong episode or misreports "not available"
  (#5).
- `_stage_ok` also rejects JSON and plain-text error bodies
  (`{"error":…}`, `Access denied`, `Not Found`, `Forbidden`) returned with
  a 200, not just HTML/XML pages (#23).

- Picker **cancel (ESC)** no longer triggers the server-2/server-3 fallback
  chain — a cancelled search exits quietly (issues #11).
- `-A -D` honours `-e N / N-M / -1` like the hicine `-D` path, and the
  `-D -e` confirm count matches what will actually download (#9, #10).
- Parallel bulk `-D` interrupts work under bash: workers are awaited by PID
  instead of dash-only bare `wait` (#12).
- `-d` downloads exit after saving — no playback menu, no misleading
  "Playing:" line (#8); downloaded titles are recorded in history.
- `episode_loop` waits only on the PID a player truly backgrounded — a stale
  `$!` is no longer awaited after foreground/`-d` runs (#16).
- popmovie `pop_m3u8`: absolute segment URIs no longer get a doubled
  `?token=?token=`, and `#EXT-X-KEY` rewrites keep the closing quote, fixing
  AES-128 streams (#6, #7).
- popmovie `pop_series` `-D` reads from a file, not a pipeline, so
  `--exit-after-play` / Ctrl-C terminate the run (#18).
- Season-ZIP labels from the API are flattened to one sanitised component —
  no path traversal out of the download dir (#14).
- `-p/-q/-e/-n/--download-dir/--page/--limit` reject a missing operand, and
  `-n` must be an integer (#19, #15).
- `tmpfile5` creation is BSD/macOS-safe (`mktemp` + rename) (#20).
- `-D` hianime gap-fill writes into the same hicine-named folder, so missing
  episodes actually land where the gap is (#21).
- Series `change_quality` lists the season's real qualities instead of a
  hardcoded 480p/720p/1080p/2160p (#22).

### Changed

- `yt-dlp` is now a first-class dependency in every package
  manifest (AUR depends, Homebrew, Scoop, Nix wraps it onto PATH,
  one-liner installer); `ffmpeg` stays the optional fallback.
- Internal dedup: `sanitize()` (was 6 inline copies), `menu_multi_flag`
  computed once, `is_series()` reuses `season_count()`.

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