{
  description = "Tmux-switcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      flake-utils,
      nixpkgs,
    }:
    let
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
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        tmux-switcher = pkgs.callPackage ./packages/default.nix { };
      in
      {
        packages.default = tmux-switcher;

        devShells.default =
          let
            tmux_conf = pkgs.writeText "tmux.conf" ''
              set -g prefix ^A
              run-shell ${tmux-switcher.rtp}
              set-option -g default-terminal 'screen-254color'
              set-option -g terminal-overrides ',xterm-256color:RGB'
              set -g default-terminal "''${TERM}"
              # display-message ${tmux-switcher.rtp}
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
      }
    ));
}
