{
  description = "vicine - search, stream, and download movies, series and anime from the terminal";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "vicine";
            version = "1.7.4";

            src = pkgs.fetchurl {
              url = "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/v1.7.4.tar.gz";
              sha256 = "6fd395aab2d13566c6b9883c000efb9d3823c4943818fbb5eba1da0b951c6cd0";
            };

            dontBuild = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              install -Dm755 "vicine-cli-${version}/vicine" "$out/bin/vicine"
              wrapProgram "$out/bin/vicine" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.fzf pkgs.mpv pkgs.yt-dlp ]}
            '';

            meta = with pkgs.lib; {
              description = "Search, stream, and download movies, series and anime from the terminal";
              homepage = "https://github.com/spaciousejar/vicine-cli";
              license = licenses.gpl3Plus;
              mainProgram = "vicine";
            };
          };
        });
    };
}