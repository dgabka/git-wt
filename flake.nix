{
  description = "A small CLI for managing Git worktrees from a bare repository";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          wt = pkgs.stdenvNoCC.mkDerivation {
            pname = "wt";
            version = "0.1.0";
            src = ./.;
            dontBuild = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              install -Dm755 $src/wt $out/bin/wt
              install -Dm644 $src/completions/wt.bash $out/share/bash-completion/completions/wt
              install -Dm644 $src/completions/_wt $out/share/zsh/site-functions/_wt
            '';
            postFixup = ''
              wrapProgram $out/bin/wt \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.bash pkgs.git pkgs.fzf ]}
            '';
          };
          default = self.packages.${system}.wt;
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ bash git fzf shellcheck shfmt zsh ];
          };
        });
    };
}
