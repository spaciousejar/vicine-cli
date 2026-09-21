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
            version = "master";

            src = pkgs.fetchurl {
              url = "https://github.com/spaciousejar/vicine-cli/archive/refs/tags/vmaster.tar.gz";
              sha256 = "02e141b6360ad200abcdeef6f0de69889e518e2aabbf753d3f50af0f0c18480c";
            };

            dontBuild = true;
            installPhase = ''
              install -Dm755 "vicine-cli-${version}/vicine" "$out/bin/vicine"
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