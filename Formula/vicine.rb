class Vicine < Formula
  desc "Search, stream, and download movies, series and anime from the terminal"
  homepage "https://github.com/spaciousejar/vicine-cli"
  url "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/v1.4.3.tar.gz"
  sha256 "02e141b6360ad200abcdeef6f0de69889e518e2aabbf753d3f50af0f0c18480c"
  license "GPL-3.0-or-later"

  depends_on "fzf"
  depends_on "jq"
  # vicine's default player on macOS is IINA; mpv is the fallback.
  # Skip the heavy mpv tree (ffmpeg, llvm, ...) with: brew install vicine --without-mpv
  depends_on "mpv" => :recommended

  def install
    bin.install "vicine"
  end

  test do
    system "#{bin}/vicine", "-V"
  end
end