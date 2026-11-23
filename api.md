# Hicine public API reference

**Status:** External observation. Every entry below comes from a direct request or a browser network event. No backend source, server shell, or Cloudflare account was available.
**Labels:** Confirmed means I observed the response. Inferred means I deduced behavior from bundle code. Unknown means source or operator access is required. Out of scope means the audit excluded the item.

**Base URL:** `https://hicine.biz`
**Transport:** HTTPS only. The site sends HSTS with `max-age=31536000; includeSubDomains`.
**Method:** GET for every observed endpoint.
**Auth:** None observed for the read endpoints. `/hapi/dl`, `/hapi/go`, and `/hapi/stream` apply a header deny check. See section 5.
**Content type:** JSON for catalog and resolution endpoints. `image/jpeg` for the image proxy. `text/html` for the SPA fallback.

## 1. Endpoint index

| Path | Query | Purpose | Auth observed | State |
|---|---|---|---|---|
| `/hapi/home` | none | Home rows and item arrays | None | Confirmed |
| `/hapi/browse` | free-form filter string | Browse the catalog | None | Confirmed |
| `/hapi/list` | `src`, `cat`, `page` | Paginated list for a source and category | None | Confirmed |
| `/hapi/search` | `q`, `page` | Title search | None | Confirmed |
| `/hapi/t` | `c` | Title detail and quality groups | None | Confirmed |
| `/hapi/g` | `k` | Episode and host list for a group | None | Confirmed |
| `/hapi/dl` | `k` | Download option list | Header check | Confirmed |
| `/hapi/go` | `k`, `m` | Resolve to a media URL or redirect | Header check | Confirmed |
| `/hapi/stream` | `k` | Stream resolution | Header check | Confirmed |
| `/hapi/img/<token>.jpg` | token in path | Image proxy | None observed | Confirmed |

## 2. Client call patterns

The bundle defines this helper set (shortened from the built file):

```js
ar = {
  home:          e       => nr('/hapi/home', e),
  browse:        (e,t)   => nr('/hapi/browse?' + e, t),
  list:          (e,t,n,r) => nr('/hapi/list?src=' + e + '&cat=' + t + '&page=' + n, r),
  search:        (e,t=1,n) => nr('/hapi/search?q=' + encodeURIComponent(e) + '&page=' + t, n),
  title:         e       => nr('/hapi/t?c=' + encodeURIComponent(e), e),
  episodes:      (e,t)   => nr('/hapi/g?k=' + encodeURIComponent(e), t),
  prefetchTitle: e       => rr('/hapi/t?c=' + encodeURIComponent(e))
}
```

The client caches GET responses for 300000 ms and holds a map of in-flight promises. On 429 and 5xx it retries after 400 ms, 1200 ms, and 2500 ms. These are client behaviors. They are not server settings.

## 3. Endpoint details

### 3.1 GET /hapi/home

Returns the landing page rows.

**Parameters:** none observed.

**Response 200.** Top-level arrays `trending`, `newEps`, `movies`, `heroes`, and a `rows` array. Each row has `src`, `cat`, `title`, and `items`. Each item has `id`, `src`, `title`, `full`, `year`, `kind`, `season`, `latest`, and `poster`. Some items also carry `backdrop`, `logo`, and `plot`. Item ids are 16 hexadecimal characters, for example `339fd3af4072b78f`.

**Evidence.** Browser loaded it with status 200 after the gate bypass. Direct probe returned 200 with the same shape.

### 3.2 GET /hapi/browse

Returns a browsable catalog section.

**Parameters:** a free-form query string. Observed values: `page=1`, `prov=netflix&page=1`, `genre=action&page=1`.

**Response 200.** JSON catalog payload. Selecting Platform `Netflix` in the browser changed the URL to `https://hicine.biz/?prov=netflix` and issued `GET /hapi/browse?prov=netflix&page=1 => [200]`. Selecting Genre `action` changed the URL to `?genre=action` and reduced the visible title links from 80 to 40.

### 3.3 GET /hapi/list

Returns a paginated list for one source and category.

**Parameters:** `src` (string), `cat` (string), `page` (integer).

**Response 200.** With `src=1&cat=1&page=1` the body was `{"items":[],"hasMore":false}`. The `hasMore` flag marks further pages.

**State.** The empty result is Confirmed. A populated result needs a valid `src` and `cat` pair from the catalog source, which was not available.

### 3.4 GET /hapi/search

Title search.

**Parameters:** `q` (query string, URL-encoded by the client), `page` (integer, default 1).

**Response 200.** JSON results. A no-match query still returns 200 with no results.

**Evidence.** `GET /hapi/search?q=zzzzqqqxxnotfound&page=1 => [200]`. The browser then showed `Nothing found for “zzzzqqqxxnotfound”`. Typing `rings` opened a results overlay and issued `GET /hapi/search?q=rings&page=1 => [200]`. Clearing the input showed `Type at least 3 letters`.

### 3.5 GET /hapi/t

Title detail.

**Parameters:** `c` (item id, URL-encoded by the client).

**Response 200.** Fields including `src`, `title`, `full`, `year`, `kind`, `imdb`, `plot`, and `shots`. The `groups` array holds quality groups with `head`, `season`, `quality`, `size`, `k`, and `zip`. The `meta` object holds `name`, `poster`, `background`, `logo`, `description`, `year`, `genres`, `cast`, `director`, `rating`, `runtime`, and `videos`. Each video has `s`, `e`, `name`, `thumb`, and `released`.

**Response 404.** With `c=test` the body was `{"error":"not found"}`.

**Browser render.** For `c=339fd3af4072b78f` the page showed `Series · Action / Adventure`, `★ 6.8 2022– Latest S3 E6 1 season 4K 1080p 720p 480p`, and six episodes with dates Nov 11 and Nov 18, 2026.

### 3.6 GET /hapi/g

Episode and host list for a quality group.

**Parameters:** `k` (group token).

**Response 200.** `zip` (boolean) and `items`. Each item has `ep` and `hosts`. Each host has `id`, `name`, and `k`. Observed host ids: `gdirect` (name G-Direct), `vcloud`, and `vdrive`.

**Response 404.** With `k=invalid` the body was `{"error":"not found"}`.

**Evidence.** The browser issued five distinct `/hapi/g?k=<token>` calls on the title page. All five returned 200. The rendered episode list held six episodes.

### 3.7 GET /hapi/dl

Download option list for one host token.

**Parameters:** `k` (host token).

**Auth.** A header deny check applies. See section 5.

**Response 200.** JSON options. Observed option names: `ten`, `fsl`, `server1`, and `pixel`. Each option carries a `k` token used by `/hapi/go`.

**Response 403.** `{"error":"forbidden"}` when the deny check fails.

**Evidence.** Browser call `/hapi/dl?k=<host_token>` returned 200 and opened the Instant, Resumable, and Mirrors source tabs.

### 3.8 GET /hapi/go

Resolves an option token to a media URL or a redirect.

**Parameters:** `k` (option token), `m` (mode). Observed modes: `d` for download, `u` for stream.

**Response 302.** With `m=d` the response carried a `Location` header. Observed `Location` hosts: Google Drive (`video-downloads.googleusercontent.com`), a Cloudflare R2 public bucket, and pixeldrain.

One observed `Location` value:

```text
https://pub-dfed992f19e6446284cd820451e160f4.r2.dev/85e0b28457d1b03e621d46d62213555b?token=1795085660
```

**Response 200.** With `m=u` and a `Referer` header the body was `{"url":"..."}`.

**Response 403.** With `m=u` and no `Referer` the body was `{"error":"forbidden"}`.

**Response 204.** With `k=invalid&m=d` the response was 204.

### 3.9 GET /hapi/stream

Stream resolution.

**Parameters:** `k` (option token).

**Auth.** A header deny check applies.

**Response 403.** With `k=invalid` the body was `{"error":"forbidden"}`. A valid token with a browser `Referer` resolved a stream in the player.

**Evidence.** Clicking Watch Episode 6 and then "Watch in browser" opened the player dialog. Play fetched a `.mkv` from `pub-19a70c9586f84745b08b3bb03beb3a18.r2.dev` with `206 Partial Content`.

### 3.10 GET /hapi/img/<token>.jpg

Image proxy.

**Parameters:** token in the path, with a `.jpg` suffix.

**Response 200.** `image/jpeg`, 90193 bytes for a genuine token.

**Tested query names.** `?url=`, `?u=`, and `?src=` each returned the same image. Those query names have no effect on the tested token.

**Tested path shapes.** An encoded URL in the path returned `404 text/html` with 146 bytes. A traversal-shaped path returned `200 text/html` with 1076 bytes. The body is still HTML, so this does not prove path disclosure.

**SSRF state.** Unknown. The token format and the proxy host allowlist are unavailable. A valid test design needs the Worker source. See report finding 6.

## 4. Token model

| Token | Where it appears | Purpose | State |
|---|---|---|---|
| `k` | `/hapi/g`, `/hapi/dl`, `/hapi/go`, `/hapi/stream` | Opaque reference: group, then host, then option | Confirmed as an opaque base64url string. Format, signature, expiry, and binding are Unknown without backend source. I did not forge one. |
| `token` | `/hapi/go` redirect target on R2 | Intended media expiry value | Ignored by the R2 bucket. Confirmed. See report finding 1. |
| gate `token` | Client URL query, checked in the bundle | Marks a visitor as verified | HMAC-SHA-256 over three dot-separated parts. The key is `hiicine_demo_secret_2025`, which is in the public bundle. A forged payload with `verified:true` and a future `exp` is accepted. Fails today. See report finding 2. |

The gate check in the bundle:

```js
let t = e.get(`token`);
let n = t ? await Jn(t) : e.get(`from`) === `hicine`;
if (n) return !0
```

## 5. Access control

The read endpoints `/hapi/home`, `/hapi/browse`, `/hapi/search`, `/hapi/t`, and `/hapi/g` returned 200 in the browser with ordinary headers and no token.

The endpoints `/hapi/dl`, `/hapi/go`, and `/hapi/stream` apply a header deny check. Results for `/hapi/dl?k=<valid>`:

| Request header | Result |
|---|---|
| none | 403 `{"error":"forbidden"}` |
| `Referer: https://hicine.biz/` | 200 |
| `Origin: https://hicine.biz` | 200 |
| `Referer: https://evil.example/` | 200 |
| `Referer: https://evil.example/hicine.biz` | 200 |

For `/hapi/home`, `Origin: https://evil.example` returns 403, but any `Referer` value returns 200. A non-browser client can set any header, so the 403 response is not an access control. See report finding 4.

## 6. Error responses

| Status | Body | When observed |
|---|---|---|
| 403 | `{"error":"forbidden"}` | `/hapi/dl` with no header; `/hapi/stream?k=invalid`; `/hapi/go?k=<valid>&m=u` with no `Referer` |
| 404 | `{"error":"not found"}` | `/hapi/t?c=test`; `/hapi/g?k=invalid` |
| 204 | empty | `/hapi/go?k=invalid&m=d` |
| 200 | SPA HTML shell | `/robots.txt`, `/sitemap.xml`, and unknown paths |

## 7. CORS and headers

The site sends HSTS `max-age=31536000; includeSubDomains`, `x-content-type-options: nosniff`, `x-frame-options: SAMEORIGIN`, CSP `frame-ancestors 'self'`, `referrer-policy: strict-origin-when-cross-origin`, and `x-robots-tag: noindex, nofollow`. The server header is `cloudflare`.

The `Origin` deny behavior on `/hapi/home` suggests an allowlist. The exact allowlist is Unknown without the Worker source.

## 8. Upstream relay

`https://relay.hekoy.workers.dev` is a separate token-gated service. `/health` returns `200` with body `ok`. The root path and a forged token return `403 {"error":"invalid token"}`. I sent the leaked HMAC token in a query value, as a Bearer token, in `X-Token`, `X-Api-Key`, `X-Relay-Token`, `X-Auth-Token`, and in a cookie. None worked. The token scheme is Unknown, and the link from `/hapi/*` to the relay is Inferred.

## 9. Media delivery

Download bucket: `pub-dfed992f19e6446284cd820451e160f4.r2.dev`. Object keys are 32 hexadecimal characters. Observed keys returned 1.77 GB and 400 MB files.

Player bucket: `pub-19a70c9586f84745b08b3bb03beb3a18.r2.dev`. A `.mkv` response was `206 Partial Content` with `Content-Length: 607457681`.

Both buckets are public and serve objects with `Cache-Control: public, max-age=604800`. The `token` query value has no effect on either bucket. Direct HEAD and GET requests returned 200 with the original token, a future token, an expired token, a text token, and no query string. See report finding 1.

## 10. Gaps that need source or operator access

- The language and framework that implement `/hapi/*`.
- The catalog data source and its update process.
- The format and binding of the `k` tokens.
- The relay token scheme and its relation to `/hapi/*`.
- The image proxy host allowlist and SSRF protection.
- Server-side rate limits and the reason for the client 429 retry logic.
- Cloudflare and R2 configuration, including bucket privacy.

**Kept as-is:** "may be encrypted or signed" and "may feed" style phrases. Changing them would change the strength of the claim.
