# vicine

[![npm version](https://img.shields.io/npm/v/vicine?logo=npm)](https://www.npmjs.com/package/vicine)
[![npm downloads](https://img.shields.io/npm/dt/vicine)](https://www.npmjs.com/package/vicine)
[![License](https://img.shields.io/npm/l/vicine)](https://github.com/spaciousejar/vicine-cli/blob/master/LICENSE)

A POSIX shell script to search, stream, and download movies, series and anime from the terminal.

## Features

- **Search** movies, series and anime by title
- **Browse** trending, recently added, and custom collections
- **Stream** directly in mpv, IINA, or VLC
- **Download** with yt-dlp, ffmpeg, or curl
- **Series support** — season/episode navigation with next/previous/replay controls
- **Anime support** — dub/sub audio via anidb.app

## Installation

### npm

Published automatically to npmjs on every new `v*` tag.

```sh
npm install -g vicine
```

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
- Installed via script/git: `vicine -U` (self-update from GitHub, upgrade-only)

## Dependencies

| Required | Optional |
|----------|----------|
| `curl` | `yt-dlp` or `ffmpeg` (for downloads) |
| `jq` | `vlc` |
| `sed`, `grep` | `iina` (macOS) |
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
vicine "jujutsu kaisen"        # Search movies/series via hicine; falls back to anidb.app
vicine -A one piece            # Search anime directly on anidb.app
vicine -A --dub -e 3 "jujutsu kaisen"  # Anime ep 3, dubbed
vicine -i batman               # Show info only (no play)
```

### Options

| Flag | Description |
|------|-------------|
| `-s`, `--search` | Search movies/series |
| `-A`, `--anime` | Search anime via anidb.app |
| `--dub` / `--sub` | Dub/sub audio for anime (default sub) |
| `-t`, `--trending` | Show trending content |
| `-r`, `--recent` | Show recently added |
| `-b`, `--browse` | Browse a collection |
| `-S`, `--stats` | Show catalogue stats |
| `-q`, `--quality` | Select quality (`best`, `480p`, `720p`, `1080p`, `4K`) |
| `-e`, `--episode` | Play episode `N`, range `N-M`, or `-1` (latest) |
| `-c`, `--continue` | Continue from watch history |
| `-C`, `--clear-history` | Clear watch history |
| `-n`, `--select-nth` | Select result by index N (non-interactive) |
| `-U`, `--update` | Self-update from GitHub (upgrade-only, refuses downgrades) |
| `--exit-after-play` | Play then exit, return player exit code |
| `-i`, `--info` | Show info only (no play) |
| `-d`, `--download` | Download instead of playing |
| `-D`, `--download-all` | Download full series or anime (all episodes) |
| `-p`, `--player` | Specify player (mpv, iina, vlc) |
| `-V`, `--version` | Show version |
| `-h`, `--help` | Show help |
| `--rofi` | Use rofi instead of fzf |
| `--dmenu` | Use dmenu instead of fzf |
| `--no-detach` | Don't detach player |
| `--download-dir` | Set download directory |
| `--page N` | Browse page number (default 1) |
| `--limit N` | Items per browse page (default 1000) |

## License

[GPL-3.0](LICENSE)