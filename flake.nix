{
  description = "Tmux-switcher";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs supportedSystems (system: function nixpkgs.legacyPackages.${system});

      overlays =
        final: prev:
        let
          tmux-switcher = prev.callPackage ./packages/default.nix { };
        in
        {
          tmuxPlugins = prev.tmuxPlugins // {
            inherit tmux-switcher;
          };
        };
    in
    {
      overlays.default = overlays;
      packages = forAllSystems (pkgs: {
        default = pkgs.callPackage ./packages/default.nix { };
      });
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
      devShells = nixpkgs.lib.genAttrs supportedSystems (system: {
        default =
          let
            pkgs = import nixpkgs { inherit system; };
            tmux-switcher = pkgs.callPackage ./packages/default.nix { };
            tmux_conf = pkgs.writeText "tmux.conf" ''
              set -g prefix ^A
              run-shell ${tmux-switcher.rtp}
            '';
          in
          pkgs.mkShell {
            buildInputs = with pkgs; [
              tmux
              fzf
              tmux-switcher
            ];

            shellHook = ''
              TMUX=
              TMUX_TMPDIR=
              ${pkgs.tmux}/bin/tmux -f ${tmux_conf}
            '';
          };
      });
    };
}
