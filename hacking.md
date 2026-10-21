# Hacking vicine

For usage and install options see the [README](README.md); for contribution
rules [CONTRIBUTING](CONTRIBUTING.md). What follows is how the scraping
works.

vicine scrapes two backends: **hicine** (movies/series) and **hianime**
(anime). Both are plain HTTP calls wrapped in POSIX shell — no build step,
no frameworks.

## Provider fallback (hicine → hianime)

Search starts on hicine (server-1). If it returns nothing or the API is
unreachable → **status codes matter**: `select_item` returns `1` for
"no results", `2` for "user cancelled" (cancelling must NOT trigger the
chain). On a genuine miss `provider_chain` runs `cmd_anime`. `-A` forces
anime only. `provider_chain` is the only place that owns this policy.

`cmd_anime` returns rather than `die`s while `_in_chain` is set, since
`die` exits the script.

`prompt_action` splits into two: `play_season_zip` handles a season that
arrives as one archive (`.season_zip`) and returns 0/1 for "handled" /
"nothing to play" — see `tests/season_zip.sh`, which stubs the network.

## Movie/series flow (hicine)

1. `cmd_search` → `GET {API}/api/search/{encoded_query}` (`API` defaults to
   `https://api.hicine.sbs`), a JSON array saved to a temp file.
2. `select_item` offers the results (fzf/rofi/dmenu or `-n`), writes the
   chosen item JSON to `tmpfile2`. Items carry `title`, `url_slug`,
   `contentType`, `links`, `season_N` fields.
3. `prompt_action` splits on `is_series`: seasons(`season_N`) → episodes,
   otherwise movies → `links`.
4. Series: `parse_episodes` turns each `Episode N : URL,SIZE,QUALITY :
   URL,SIZE,QUALITY : …` line into `ep\url\qual\size` rows (last variant =
   best; `-q` picks a matching variant). `episode_loop` plays/resolves each.
5. Movies: `parse_links` turns `URL, Link2, …, Description, Size` rows into
   `url\tdesc\tsize`; `movie_playable` walks the candidates — requested
   quality first, then the rest by resolution — resolving each and
   body-sniffing the first 32 bytes until one serves media (HTML pages at
   200, JSON, 404 bodies are rejected like `_stage_ok` does for downloads).
   Useless dead best-variant entries are why: sources lose files without
   losing rows.
6. `resolve_stream_url` resolves the workers URLs: a `vcloud=` token is
   scraped via `{base}/api/links?vcloud=…` (retried up to 5× while
   `"tokens":{}`), then `{base}/go?type=…&vcloud=…&ts=…&sig=…` redirects to
   the real CDN URL. URLs with an empty `vcloud=` are dead API placeholders
   and fail resolution (skip, don't pass through).
7. `-D` narrows downloads per `-e N / N-M / -1` via `eps_by_request`
   (`tests/eps_by_request.sh`) — the same helper feeds the confirm count so
   the prompt can't disagree with what downloads. Anime-type hicine titles
   with missing episodes are gap-filled through hianime into the same
   `$_safe` folder.

## Anime flow (hianime)

1. `anidb_search`: `GET https://hianime.at/search?keyword=…`, HTML parsed
   into `anime_id\tTitle` lines via the `data-id`/`title` attributes.
   An empty (non-block) page 1 is retried at `&page=2` once — a title
   beyond the first page is a real miss only after that.
2. `anidb_episodes`: `GET /api/theme/episode/list/{id}` returns JSON with an
   `.html` fragment → `ep_id\tep_no`.
3. `anidb_m3u8`: `GET /api/theme/episode/servers?episodeId={ep_id}` → find
   the ZokoAnime `server-item` (only ZokoAnime embeds are decodable;
   MegaPlay/Vidstream need AES) → its base64 `data-hash` decodes to the
   embed URL on `zokoanime.video` → the page's `window.__P` blob is
   XOR("otaku-embed-v1") of base64 JSON → the m3u8 `src`.
4. `anime_variants` (the m3u8 variant parser, `tests/m3u8_variants.sh`)
   lists `RESp>URL` lines; `anime_pick_quality` picks by `-q`. These
   streams live on `hls.1embed.buzz`, which is **referer-gated** —
   every request must carry `Referer: https://zokoanime.video/`.
5. The episode picker displays `<row> <ep>`; the row is mapped back through
   the list (`sed -n "${row}p"`) so non-contiguous numbering (0-specials,
   S2@13) plays the right episode (`tests/anime_picker.sh`).
6. A split-cour anime lists its episode numbers **twice** under different
   internal ids — `anidb_episodes` dedups the whole `id<TAB>number` row, not
   the number, so both survive. The `-D` loop therefore tags every row with
   which run of a number it is (one awk pass) and passes that occurrence to
   `anime_play_episode`, which picks `season-N/SNE##` from it. Without that
   the second cour landed on the first one's file, `dl_find` reported
   "Already exists", and half the series was silently skipped
   (`tests/anime_plumbing.sh`).


## Debugging

- Trace a run: `sh -x vicine <query> -n 0` (auto-picks the first result).
- Probe an endpoint by hand:
  ```sh
  curl -s "https://api.hicine.sbs/api/search/one%20piece"
  curl -s "https://hianime.at/api/theme/episode/list/one-piece-100"
  ```
- Provider broke? The failure mode is usually one regex not matching the
  new HTML/JSON. Grab the raw response, diff it against the pattern in the
  parser, adjust, and re-test with `sh -x`.
- Shell differences matter: `/bin/sh` is dash on Debian/Ubuntu and bash on
  Arch/Fedora. CI runs the whole suite under `sh`, `dash` and `bash`. 
  `tests/args.sh` also accepts `VICINE="bash ../vicine"` to exercise the
  real script under a specific interpreter. CI also runs the suite on
  **macOS**, whose userland is BSD. There, a util-linux-only command
  (`rev`, `cut -d, -f2-` quirks, bare `mktemp`) appears as an empty result
  instead of a working one.
- Is the provider itself broken? `VICINE_LIVE=1 sh tests/live.sh` searches
  the real hicine and hianime APIs and reports whether the rows still parse.
  The daily `live.yml` run makes that check.
- Did a release reach the users? `sh scripts/verify-channels.sh
  1.7.2` probes npm, the GitHub Release, the AUR, the Homebrew tap, the
  Scoop bucket, the Nix flake and the Ubuntu PPA. A green release workflow
  shows the upload went out. It does not show that a channel serves the
  release.

## Architecture notes

- `VICINE_LIB=1 vicine` defines every function and returns before the `Main`
  section, so a test can `. ./vicine` and call the real implementations.
  This is how the suites work — they used to `eval` functions sed-extracted
  from the file, which could silently keep passing against a stale copy.
- State lives in `mktemp` files: `tmpfile` = search JSON, `tmpfile2` =
  selected item, `tmpfile3` = menu lists, `tmpfile4` = player log.
  An EXIT trap cleans them and preserves the exit code; Ctrl-C is 130,
  HUP/TERM are 129/143. Every staging file is created with `mktemp` — a
  fixed name is a data race between two copies (the history file's
  `$histfile.tmp` used to be one) and a symlink-clobber target.
- Menu/list plumbing is shared, not copy-pasted: `season_menu`,
  `numbered_menu`, `pick_quality_menu` and `movie_playable`. Season data is
  read once per item by `season_fields` (one `jq` call for every
  `season_N`), not twenty `jq` calls scanning 1..20.
- Exit codes matter: `die` → 1, interrupts → 130, player exit codes pass
  through with `--exit-after-play`.
- Quality is normalized lowercase and `4k` → `2160p` before any matching.
- Download chain: yt-dlp → ffmpeg → curl, staged through `.part` with an
  atomic rename; every URL is probed first with a 1-byte range request —
  401/403/404/410 fail fast with one message instead of burning the whole
  chain (dead CDN bucket); `_stage_ok` rejects HTML/XML/JSON and plain-text
  error bodies; an existing non-empty file short-circuits ("Already
  exists").
- Parallel `-D` loops (`VICINE_DL_JOBS`, default 1 = serial) resolve + download in
  subshell workers, awaiting each job by PID — dash's bare `wait` returns
  the last job's status, bash/POSIX return 0, so the pids are waited
  individually to keep Ctrl-C working under every shell.
- `-d` downloads without the playback menu and writes a history row per
  successful download, so it resurfaces under `-c` (dedup keeps one line
  per title). An episode range (`-e N-M`, multi-select included) runs to
  its end — next existing episode, keeps going past a failure — not just
  the first file (`tests/dl_range.sh`); `episode_loop` waits only on a PID
  a player genuinely backgrounded.