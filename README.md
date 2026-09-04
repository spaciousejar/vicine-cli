# vicine

A POSIX shell script to search, stream, and download movies and series from the terminal.

## Features

- **Search** movies and series by title
- **Browse** trending, recently added, and custom collections
- **Stream** directly in mpv, IINA, or VLC
- **Download** with yt-dlp, ffmpeg, or curl
- **Series support** — season/episode navigation with next/previous/replay controls
- **Fuzzy finder** integration via fzf, rofi, or dmenu

## Installation

```sh
git clone https://github.com/spaciousejar/vicine-cli.git
cd vicine-cli
chmod +x vicine
```

Optionally, add it to your `$PATH`:

```sh
sudo cp vicine /usr/local/bin/vicine
```

## Dependencies

| Required | Optional |
|----------|----------|
| `curl` | `yt-dlp` or `ffmpeg` (for downloads) |
| `jq` | `vlc` |
| `sed`, `grep` | |
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
vicine -b bolly_movies         # Browse a collection
vicine -i batman               # Show info only (no play)
```

### Options

| Flag | Description |
|------|-------------|
| `-s`, `--search` | Search movies/series |
| `-t`, `--trending` | Show trending content |
| `-r`, `--recent` | Show recently added |
| `-b`, `--browse` | Browse a collection |
| `-i`, `--info` | Show info only (no play) |
| `-d`, `--download` | Download instead of playing |
| `-D`, `--download-all` | Download all quality variants |
| `-p`, `--player` | Specify player (mpv, iina, vlc) |
| `-V`, `--version` | Show version |
| `-h`, `--help` | Show help |
| `--rofi` | Use rofi instead of fzf |
| `--dmenu` | Use dmenu instead of fzf |
| `--no-detach` | Don't detach player |
| `--download-dir` | Set download directory |

