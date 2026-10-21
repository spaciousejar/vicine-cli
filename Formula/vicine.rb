class Vicine < Formula
  desc "Search, stream, and download movies, series and anime from the terminal"
  homepage "https://github.com/spaciousejar/vicine-cli"
  url "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/v1.7.2.tar.gz"
  sha256 "0d9b271f632ce9dceba6f1391f39db21c9b17865706a88f1e90df01f94a8ed1c"
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