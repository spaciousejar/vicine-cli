# Hacking vicine

vicine scrapes three backends: **hicine** (movies/series), **popmovie**
(TMDB/vidsrc backup), and **hianime** (anime). All are plain HTTP APIs
wrapped in POSIX shell — no build step, no frameworks.

## Provider fallback (server-1 → server-2 → server-3)

Search starts on server-1 (hicine). If it returns nothing, the API is
unreachable, or the user cancels → **same status codes matter**: `select_item`
returns `1` for "no results", `2` for "user cancelled" (cancelling must NOT
trigger the chain). On a genuine miss, `pop_search` (server-2) runs, and
only if that also fails does `cmd_anime` (server-3) run. `-D` downloads
failed hicine movies are retried through server-2. `VICINE_PROVIDER=popmovie`
forces server-2 only; `-A` forces server-3 only.

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
   `url\tdesc\tsize`; `movie_best_url` sorts by resolution (highest = best).
6. `resolve_stream_url` resolves the workers URLs: a `vcloud=` token is
   scraped via `{base}/api/links?vcloud=…` (retried up to 5× while
   `"tokens":{}`), then `{base}/go?type=…&vcloud=…&ts=…&sig=…` redirects to
   the real CDN URL. URLs with an empty `vcloud=` are dead API placeholders
   and fail resolution (skip, don't pass through).
7. `-D` narrows downloads per `-e N / N-M / -1` via `eps_by_request`
   (`tests/eps_by_request.sh`) — the same helper feeds the confirm count so
   the prompt can't disagree with what downloads. Anime-type hicine titles
   with missing episodes are gap-filled through server-3 into the same
   `$_safe` folder.

## Anime flow (hianime)

1. `anidb_search`: `GET https://hianime.at/search?keyword=…`, HTML parsed
   into `anime_id\tTitle` lines via the `data-id`/`title` attributes.
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

## Backup provider flow (popmovie)

`pop_search` → TMDB search via `popmovie.online/api/tmdb/…` (movies and
tv). `pop_resolve` asks `data.vidsrc.sh/api.php` for stream URLs; encrypted
payloads decrypt via a node+wasm step. `pop_m3u8` rewrites the playlist to
absolute, token-stamped segment/key URIs (the stamp is in awk; guarded by
`tests/pop_m3u8.sh` — keep the `#EXT-X-KEY` rewrite single-pass, a
`while(match())` there loops forever once the closing quote is restored).

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
  Arch/Fedora. CI runs the whole suite under `sh`, `dash` and `bash` —
  `tests/args.sh` also accepts `VICINE="bash ../vicine"` to exercise the
  real script under a specific interpreter.

## Architecture notes

- State lives in five `mktemp` files: `tmpfile` = search JSON,
  `tmpfile2` = selected item, `tmpfile3` = menu lists, `tmpfile4` = player
  log, `tmpfile5` = popmovie's rewritten `.m3u8` playlist (created via
  `mktemp` + rename so BSD/macOS accepts it). An EXIT trap cleans them and
  preserves the exit code; Ctrl-C is 130.
- Exit codes matter: `die` → 1, interrupts → 130, player exit codes pass
  through with `--exit-after-play`.
- Quality is normalized lowercase and `4k` → `2160p` before any matching.
- Download chain: yt-dlp → ffmpeg → curl, staged through `.part` with an
  atomic rename; every URL is probed first with a 1-byte range request —
  401/403/404/410 fail fast with one message instead of burning the whole
  chain (dead CDN bucket); `_stage_ok` rejects HTML/XML/JSON and plain-text
  error bodies; an existing non-empty file short-circuits ("Already
  exists").
- Parallel `-D` loops (`VICINE_DL_JOBS`, default 2) resolve + download in
  subshell workers, awaiting each job by PID — dash's bare `wait` returns
  the last job's status, bash/POSIX return 0, so the pids are waited
  individually to keep Ctrl-C working under every shell.
- `-d` exits after a download (no playback menu, nothing recorded as
  watched); `episode_loop` waits only on a PID a player genuinely
  backgrounded.