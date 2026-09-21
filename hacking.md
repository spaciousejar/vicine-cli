# Hacking vicine

vicine scrapes two backends: **hicine** (movies/series) and **hianime**
(anime). Both are plain HTTP APIs wrapped in POSIX shell — no build step,
no frameworks.

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
   `url\tdesc\tsize`; the last link is treated as best.
6. `resolve_stream_url` resolves the workers URLs: a `vcloud=` token is
   POSTed/scraped via `{base}/api/links?vcloud=…` (retried up to 5× while
   `"tokens":{}`), then `{base}/go?type=…&vcloud=…&ts=…&sig=…` redirects to
   the real CDN URL. URLs with an empty `vcloud=` are dead API placeholders
   and fail resolution (skip, don't pass through).

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

## Architecture notes

- State lives in four `mktemp` files: `tmpfile` = search JSON,
  `tmpfile2` = selected item, `tmpfile3` = menu lists, `tmpfile4` = player
  log. An EXIT trap cleans them and preserves the exit code; Ctrl-C is 130.
- Exit codes matter: `die` → 1, interrupts → 130, player exit codes pass
  through with `--exit-after-play`.
- Quality is normalized lowercase and `4k` → `2160p` before any matching.
- Download chain: yt-dlp → ffmpeg → curl, staged through `.part` with an
  atomic rename; `_stage_ok` rejects HTML/XML error pages; an existing
  non-empty file short-circuits ("Already exists").
- Parallel `-D` loops (`VICINE_DL_JOBS`, default 2) resolve + download in
  subshell workers; a worker exit ≥ 130 stops the batch.