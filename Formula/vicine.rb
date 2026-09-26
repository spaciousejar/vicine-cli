class Vicine < Formula
  desc "Search, stream, and download movies, series and anime from the terminal"
  homepage "https://github.com/spaciousejar/vicine-cli"
  url "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/v1.5.1.tar.gz"
  sha256 "324783d08294f1ee8e19113c220158510c7a5295d569db8f8cc6f251f8a96bb0"
  license "GPL-3.0-or-later"

  depends_on "fzf"
  depends_on "jq"
  depends_on "yt-dlp"   # primary downloader; ffmpeg stays an optional fallback
  # vicine's default player on macOS is IINA; brew skips the cask
  # automatically when IINA is already installed. Add your own player
  # (e.g. mpv via `brew install mpv`, or use -p vlc) if IINA is unwanted.
  depends_on cask: "iina"

  def install
    bin.install "vicine"
  end

  test do
    system "#{bin}/vicine", "-V"
  end
end