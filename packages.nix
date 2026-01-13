{ pkgs }:
{
  # Derivation containing all alias files
  aliases = pkgs.runCommand "dot-files-aliases" { } ''
    mkdir -p $out
    cp -r ${./aliases}/* $out/
  '';

  # Derivation containing all scripts
  scripts = pkgs.runCommand "dot-files-scripts" { } ''
    mkdir -p $out/bin
    cp -r ${./scripts}/* $out/bin/
    # Make all scripts executable
    chmod +x $out/bin/*
  '';

  # Derivation containing all completion files
  completions = pkgs.runCommand "dot-files-completions" { } ''
    mkdir -p $out
    cp -r ${./completions}/* $out/
  '';

  # Derivation containing all config files
  configs = pkgs.runCommand "dot-files-configs" { } ''
    mkdir -p $out
    cp -r ${./.config}/* $out/
  '';

  # Convenience derivation that includes the welcome script
  welcome = "${./10-welcome}";
}
