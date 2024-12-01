{
  lib,
  tmuxPlugins,
}:
tmuxPlugins.mkTmuxPlugin {
  pluginName = "tmux-switcher";
  version = "unstable-2024-12-02";
  src = ../.;
  meta = with lib; {
    license = licenses.mit;
    platforms = platforms.unix;
  };
  postInstall = ''
    sed -i -e 's|''${TMUX_PLUGIN_MANAGER_PATH%/}|${placeholder "out"}/share/tmux-plugins|g' $target/libexec/switcher.bash
  '';
}
