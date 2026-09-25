# vicine

[![npm version](https://img.shields.io/npm/v/vicine?logo=npm)](https://www.npmjs.com/package/vicine)
[![npm downloads](https://img.shields.io/npm/dt/vicine)](https://www.npmjs.com/package/vicine)
[![AUR version](https://img.shields.io/aur/version/vicine)](https://aur.archlinux.org/packages/vicine)
[![License](https://img.shields.io/npm/l/vicine)](https://github.com/spaciousejar/vicine-cli/blob/master/LICENSE)

A POSIX shell script to search, stream, and download movies, series and anime from the terminal.

See the [CHANGELOG](CHANGELOG.md) for release history.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Releasing](#releasing)
- [Dependencies](#dependencies)
- [Usage](#usage)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Search** movies, series and anime by title
- **Browse** trending, recently added, and custom collections
- **Stream** directly in mpv, IINA, or VLC
- **Download** with yt-dlp, ffmpeg, or curl
- **Series support** — season/episode navigation with next/previous/replay controls
- **Anime support** — dub/sub audio via hianime.at
- **Automatic provider fallback** — when the primary catalogue (server-1)
  has no result or is down, the search falls back to the popmovie backup
  (server-2), then the hianime anime catalogue (server-3)

> Anime streams are pulled from the ZokoAnime server. Some titles only offer
> MegaPlay-based servers, which can't be resolved by the script — those show
> "No sources found".

## Backup provider (server-2, popmovie)

The popmovie catalogue (TMDB + vidsrc.sh streams) is the **automatic
fallback**: if a server-1 search returns nothing, or the hicine API is
unreachable, vicine retries the title there before the anime catalogue.
It can also be forced as the sole provider:

```sh
VICINE_PROVIDER=popmovie vicine "the batman"
VICINE_PROVIDER=popmovie vicine -q 1080p -D reacher
```

Notes: episodes resolve per (tmdb id, season, episode); the quality ladder
is inside the resolved playlist (`-q` selects the matching variant);
encrypted stream payloads need `node` (usually already present via npm).
Playback pipes the stamped playlist through `yt-dlp` into the player —
that sidesteps mpv's local-playlist network whitelist, but the pipe means
no seeking (backup-provider tradeoff). Trending/recent/stats, anime
(`-A`), and the watch history (uses TMDB ids) work as usual.

## Installation

Packaged installs below, or run anywhere via the [one-liner
installer](#one-liner-installer).

### macOS

- **Homebrew** (tap provided by this repo):
  ```sh
  brew tap spaciousejar/vicine-cli
  brew trust spaciousejar/vicine-cli   # required by Homebrew 6.0+ tap-trust
  brew install vicine
  ```
  Installs `jq`, `fzf`, and the IINA app (vicine's default player on
  macOS); brew skips IINA automatically when it's already installed. Use
  `-p vlc` or `brew install mpv` if you don't want IINA.
- **npm**: `npm install -g vicine`

### Windows

- **Scoop** — the `vicine` command wraps the Git Bash `bash.exe` that ships
  with the `git` dependency, so no extra WSL/terminal setup is needed:
  ```sh
  scoop bucket add extras          # mpv and friends live here
  scoop bucket add vicine-cli https://github.com/spaciousejar/vicine-cli
  scoop install vicine-cli/vicine
  ```
  Add a player (`scoop install extras/mpv`, IINA, or VLC) — vicine has no
  bundled player on Windows; `yt-dlp` from `extras` enables downloads.
- **WSL**: follow the Linux steps below.

### Linux

- **AUR (Arch)**: `yay -S vicine`
- **Nix**: `nix profile install github:spaciousejar/vicine-cli`
- **npm**: `npm install -g vicine`
- **One-liner installer**
- **Manual (git)**

### One-liner installer

```sh
curl -fsSL https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/install.sh | sh
```

System-wide (requires root):

```sh
curl -fsSL https://raw.githubusercontent.com/spaciousejar/vicine-cli/master/install.sh | sudo sh -s /usr/local/bin
```

### Manual (git)

```sh
git clone https://github.com/spaciousejar/vicine-cli.git
cd vicine-cli
chmod +x vicine
```

Optionally, add it to your `$PATH`:

```sh
sudo cp vicine /usr/local/bin/vicine
```

### Updating

- Installed via npm: `npm update -g vicine`
- Installed via AUR: `yay -S vicine` / `paru -S vicine` — **do not use
  `vicine -U`**: `/usr/bin/vicine` is root-owned and pacman-managed, so the
  self-update cannot (and should not) write it
- Installed via Homebrew: `brew trust spaciousejar/vicine-cli && brew upgrade vicine`
- Installed via Nix: `nix profile upgrade github:spaciousejar/vicine-cli`
- Installed via script/git: `vicine -U` (self-update from GitHub, upgrade-only)

### Uninstalling

- Installed via npm: `npm uninstall -g vicine`
- Installed via AUR: `sudo pacman -R vicine`
- Installed via Homebrew: `brew uninstall vicine && brew untap spaciousejar/vicine-cli`
- Installed via Nix: `nix profile remove vicine`
- Installed via script/git — the script removes itself:

  ```sh
  vicine --uninstall
  ```

- Watch history under `~/.local/share/vicine` is kept; delete it manually if you want it gone.

## Releasing

Releases are fully automated — one tag push is enough:

```sh
# bump the version in `vicine` (version_number), `package.json`, and the
# CHANGELOG (move [Unreleased] to a dated release section); run the
# self-checks (`sh tests/*.sh`); commit, then:
git tag -a v1.5.0 -m "v1.5.0"
git push origin v1.5.0
```

`.github/workflows/publish.yml` then:

1. publishes `vicine@<version>` to npmjs
2. creates a GitHub Release with notes generated from the commits since the previous tag (skipped if the release already exists)

Publishing the release triggers [`.github/workflows/aur.yml`](.github/workflows/aur.yml), which bumps `pkgver`, recomputes the checksum, and pushes the AUR package (`aur/PKGBUILD`). It needs the `AUR_SSH_PRIVATE_KEY` repo secret (the SSH key registered at aur.archlinux.org).

[`.github/workflows/pkg-bump.yml`](.github/workflows/pkg-bump.yml) keeps the
repo-hosted packages current: on every release it rewrites the version and
checksum pins in the Homebrew formula (`Formula/vicine.rb`), the Scoop
manifest (`bucket/vicine.json`), and the Nix flake (`flake.nix`). It works
on `master` (not the tag ref) so its auto-commit can push.

[`.github/workflows/release-verify.yml`](.github/workflows/release-verify.yml)
then fails loudly if those pins didn't advance to the new tag, and
[`.github/workflows/tests.yml`](.github/workflows/tests.yml) runs the
self-checks (under `sh`, `dash` and `bash`) on every push and PR.

> Debian/Ubuntu (PPA): `.github/workflows/ppa.yml` builds and uploads a
> source package to `ppa:spaciousejar/vicine` on launchpad.net (needs the
> `PPA_GPG_PRIVATE_KEY` / `PPA_SSH_PRIVATE_KEY` secrets, already set).
> Fedora/COPR and openSUSE/OBS aren't hosted yet —
> they need accounts on copr.fedorainfracloud.org / build.opensuse.org.
> Until then, vicine installs on those distros via npm, the one-liner, or
> git.

## Dependencies

| Required | Optional |
|----------|----------|
| `curl` | `yt-dlp` or `ffmpeg` (for downloads) |
| `jq` | `vlc` |
| `sed`, `grep`, `awk` | `iina` (macOS) |
| `base64`, `od` (anime provider) | |
| `fzf` (or `rofi`/`dmenu`) | |
| `mpv` (or `iina` on macOS) | |

## Usage

```
vicine [options] [query]
```

### Examples

```sh
vicine batman                  # Search and play "batman"
vicine -s "death of robin hood" # Explicit search
vicine -t movies               # Browse trending movies
vicine -r                      # Recently added
vicine -d euphoria             # Download instead of play
vicine -b bollywood_movies --page 2 --limit 50   # Browse a collection page
vicine -S                      # Show catalogue stats
vicine -q 720p -e 3 stranger things   # Play ep 3 in 720p
vicine -q 1080p -e 5-8 stranger things # Play eps 5-8 in 1080p
vicine -c                      # Continue from watch history
vicine -n 1 batman             # Play 2nd search result (non-interactive)
vicine "jujutsu kaisen"        # Search movies/series via hicine; falls back to hianime.at
vicine -A one piece            # Search anime directly on hianime.at
vicine anime "one piece"       # Bare `anime` keyword — same as -A
vicine -A --dub -e 3 "jujutsu kaisen"  # Anime ep 3, dubbed (dub is the default)
vicine -D -A "one piece"       # Download every episode of an anime
vicine -D -e 3-8 "stranger things"  # Download only eps 3-8 of a series
vicine -i batman               # Show info only (no play)
```

`-D` downloads land in `~/Movies/<Title>/season-N/` (override with
`VICINE_DOWNLOAD_DIR`), several episodes in parallel (`VICINE_DL_JOBS`,
default 2). Movies keep the flat layout.

### Options

| Flag | Description |
|------|-------------|
| `anime` | Bare keyword alias for `-A` (search anime via hianime.at) |
| `-s`, `--search` | Search movies/series/anime |
| `-A`, `--anime` | Search anime via hianime.at |
| `--dub` / `--sub` | Dub/sub audio for anime (default dub; `VICINE_ANIME_MODE=sub` to switch) |
| `-t`, `--trending` | Show trending content |
| `-r`, `--recent` | Show recently added |
| `-b`, `--browse` | Browse a collection |
| `-S`, `--stats` | Show catalogue stats |
| `-q`, `--quality` | Select quality (`best`, `480p`, `720p`, `1080p`, `2160p`; `4K` accepted as an alias) |
| `-e`, `--episode` | Play episode `N`, range `N-M`, or `-1` (latest); also limits `-D` downloads |
| `-c`, `--continue` | Continue from watch history |
| `-C`, `--clear-history` | Clear watch history |
| `-n`, `--select-nth` | Select result by index N (non-interactive) |
| `-U`, `--update` | Self-update from GitHub (upgrade-only, refuses downgrades) |
| `--uninstall` | Remove the script from disk (history is kept) |
| `--exit-after-play` | Play then exit, return player exit code |
| `-i`, `--info` | Show info only (no play) |
| `-d`, `--download` | Download instead of playing |
| `-D`, `--download-all` | Download a movie, whole series, or anime — interactive quality/season pickers, parallel downloads (`VICINE_DL_JOBS`) |
| `-p`, `--player` | Specify player (mpv, iina, vlc) |
| `-V`, `-v`, `--version`, `--v` | Show version |
| `-h`, `--help` | Show help |
| `--rofi` | Use rofi instead of fzf |
| `--dmenu` | Use dmenu instead of fzf |
| `--no-detach` | Don't detach player |
| `--download-dir` | Set download directory |
| `--page N` | Browse page number (default 1) |
| `--limit N` | Items per browse page (default 1000) |

## FAQ

- **How do I choose the quality?** `-q`/`--quality` (`best`, `480p`, `720p`,
  `1080p`, `2160p`; `4K` is accepted as an alias).
- **Where do downloads go?** `~/Movies/<Title>/season-N/` by default; set
  `VICINE_DOWNLOAD_DIR` to change it. Movies keep the flat layout.
- **Can I watch dubbed anime?** Yes — dub is the default; use `--sub` (or
  `VICINE_ANIME_MODE=sub`) for subtitled Japanese.
- **Can I use VLC or IINA instead of mpv?** Yes — `-p vlc` / `-p iina`, or
  set `VICINE_PLAYER`.
- **How do I download a whole series or anime?** `-D` downloads every
  episode (movies, series and anime); anime prompts for an episode range
  (e.g. `1-50`), series for the seasons. Non-TTY runs download everything at
  the chosen quality.
- **A title shows "No sources found"** — that server is MegaPlay-based and
  can't be resolved by the script; see the note under
  [Features](#features).
- **How do I update?** `npm update -g vicine`, `yay -S vicine` / `paru -S
  vicine` (AUR), `brew upgrade vicine`, or `vicine -U` for script installs.
  If something breaks, update first — stale versions hit retired provider
  endpoints.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for guidelines, [hacking](hacking.md)
for how the scraping works, and the [legal disclaimer](disclaimer.md).

## License

[GPL-3.0](LICENSE)