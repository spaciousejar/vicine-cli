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

> Anime streams are pulled from the ZokoAnime server. Some titles only offer
> MegaPlay-based servers, which can't be resolved by the script — those show
> "No sources found".

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
  Installs `jq`, `fzf`, and the IINA app (vicine's default player on macOS).
  Skip IINA with `brew install vicine --without-iina` (then use VLC via
  `-p vlc`, or install mpv yourself).
- **npm**: `npm install -g vicine`

### Windows

- **Scoop** (between Git Bash; start vicine from a Git Bash terminal);
  deps: `scoop install git jq fzf mpv` (+ `yt-dlp` for downloads):
  ```sh
  scoop bucket add vicine-cli https://github.com/spaciousejar/vicine-cli
  scoop install vicine-cli/vicine
  ```
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
- Installed via AUR: `yay -S vicine` (or a regular `pacman -Syu` once installed)
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
# CHANGELOG (move [Unreleased] to a dated release section); commit, then:
git tag -a v1.3.0 -m "v1.3.0"
git push origin v1.3.0
```

`.github/workflows/publish.yml` then:

1. publishes `vicine@<version>` to npmjs
2. creates a GitHub Release with notes generated from the commits since the previous tag (skipped if the release already exists)

Publishing the release triggers [`.github/workflows/aur.yml`](.github/workflows/aur.yml), which bumps `pkgver`, recomputes the checksum, and pushes the AUR package (`aur/PKGBUILD`). It needs the `AUR_SSH_PRIVATE_KEY` repo secret (the SSH key registered at aur.archlinux.org).

[`.github/workflows/pkg-bump.yml`](.github/workflows/pkg-bump.yml) keeps the
repo-hosted packages current: on every release it rewrites the version and
checksum pins in the Homebrew formula (`Formula/vicine.rb`), the Scoop
manifest (`bucket/vicine.json`), and the Nix flake (`flake.nix`).

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
vicine -A --dub -e 3 "jujutsu kaisen"  # Anime ep 3, dubbed
vicine -D -A "one piece"       # Download every episode of an anime
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
| `--dub` / `--sub` | Dub/sub audio for anime (default sub) |
| `-t`, `--trending` | Show trending content |
| `-r`, `--recent` | Show recently added |
| `-b`, `--browse` | Browse a collection |
| `-S`, `--stats` | Show catalogue stats |
| `-q`, `--quality` | Select quality (`best`, `480p`, `720p`, `1080p`, `2160p`; `4K` accepted as an alias) |
| `-e`, `--episode` | Play episode `N`, range `N-M`, or `-1` (latest) |
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
- **Can I watch dubbed anime?** Yes — `--dub` (default is subtitled).
- **Can I use VLC or IINA instead of mpv?** Yes — `-p vlc` / `-p iina`, or
  set `VICINE_PLAYER`.
- **How do I download a whole series or anime?** `-D` downloads every
  episode (movies, series and anime); anime prompts for an episode range
  (e.g. `1-50`), series for the seasons. Non-TTY runs download everything at
  the chosen quality.
- **A title shows "No sources found"** — that server is MegaPlay-based and
  can't be resolved by the script; see the note under
  [Features](#features).
- **How do I update?** `npm update -g vicine`, `yay -S vicine`, or `vicine
  -U` for script installs. If something breaks, update first — stale
  versions hit retired provider endpoints.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for guidelines, [hacking](hacking.md)
for how the scraping works, and the [legal disclaimer](disclaimer.md).

## License

[GPL-3.0](LICENSE)