{
  description = "Pick a web link from a Zellij pane with fzf";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { nixpkgs, ... }:
    let
      forSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      checks = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          picker =
            pkgs.runCommand "urlview-check"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gawk
                  gnugrep
                  gnused
                ];
              }
              ''
                bash ${./test.sh} ${./zellij-urlview.sh}
                touch "$out"
              '';
        }
      );
      packages = forSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          zellij-urlview = pkgs.writeShellApplication {
            name = "zellij-urlview";
            runtimeInputs = with pkgs; [
              coreutils
              fzf
              gawk
              gnugrep
              gnused
            ];
            bashOptions = [ "nounset" ];
            text = builtins.readFile ./zellij-urlview.sh;
          };
        in
        {
          inherit zellij-urlview;
          default = zellij-urlview;
        }
      );
    };
}
