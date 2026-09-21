class Vicine < Formula
  desc "Search, stream, and download movies, series and anime from the terminal"
  homepage "https://github.com/spaciousejar/vicine-cli"
  url "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/vmaster.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "GPL-3.0-or-later"

  depends_on "fzf"
  depends_on "jq"
  depends_on "mpv"

  def install
    bin.install "vicine"
  end

  test do
    system "#{bin}/vicine", "-V"
  end
end