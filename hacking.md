# Hacking vicine

For usage and install options see the [README](README.md); for contribution
rules [CONTRIBUTING](CONTRIBUTING.md). What follows is how the scraping
works.

vicine scrapes several backends: **hicine** (movies/series), **hianime**
(anime) and **vegamovies.gallery** (last resort). All are plain
HTTP calls wrapped in POSIX shell — no build step, no frameworks.

## Provider fallback (server-1 → server-2 → server-3)

Search starts on server-1 (hicine). If it returns nothing or the API is
unreachable → **status codes matter**: `select_item` returns `1` for
"no results", `2` for "user cancelled" (cancelling must NOT trigger the
chain). On a genuine miss `provider_chain` runs `cmd_mirrors` → `cmd_anime`,
each tried until one returns 0 — film sources before the anime one, so a
general query does not land on an anime-only catalogue first. `-A` forces anime only, `-z` forces the
mirrors. `provider_chain` is the only place that owns this policy.

`prompt_action` splits into two: `play_season_zip` handles a season that
arrives as one archive (`.season_zip`) and returns 0/1 for "handled" /
"nothing to play" — see `tests/season_zip.sh`, which stubs the network.

`cmd_mirrors` searches every host in `MIRROR_HOSTS` and merges the results into
one list, each row tagged with its host (field 4) — the page referer and the
history key both need it. Each host's search is a sitemap pull
(`mirror_sitemaps` parses the index; the post-sitemap count and naming differ
per host, 3 to 34), fetched 8-way parallel by `mirror_ua_fetch`, then grepped
for the slug. All four together is ~15 s and ~14 MB, paid only after hicine
and hianime have both missed.

`-z` skips the first two providers and goes straight to the mirrors; `-z HOST`
restricts it to one. The host is matched against `MIRROR_HOSTS` by full name or
first label, and an unmatched word stays part of the query rather than erroring —
so a typo degrades to a plain mirror search rather than a confusing error.

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

- `VICINE_LIB=1 vicine` defines every function and returns before the `Main`
  section, so a test can `. ./vicine` and call the real implementations.
  This is how the suites work — they used to `eval` functions sed-extracted
  from the file, which could silently keep passing against a stale copy.
- State lives in `mktemp` files: `tmpfile` = search JSON, `tmpfile2` =
  selected item, `tmpfile3` = menu lists, `tmpfile4` = player log.
  An EXIT trap cleans them and preserves the exit code; Ctrl-C is 130,
  HUP/TERM are 129/143.
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
- `-d` exits after a download (no playback menu, nothing recorded as
  watched); `episode_loop` waits only on a PID a player genuinely
  backgrounded.