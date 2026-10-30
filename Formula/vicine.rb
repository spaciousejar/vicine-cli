class Vicine < Formula
  desc "Search, stream, and download movies, series and anime from the terminal"
  homepage "https://github.com/spaciousejar/vicine-cli"
  url "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/v1.7.5.tar.gz"
  sha256 "2e6816562cb329ce0ef81e93ea448ee6d9fb36b67e9c897f398a7b32a64fb771"
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