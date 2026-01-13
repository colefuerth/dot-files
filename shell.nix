{ pkgs, dotFilesPackages }:

let
  # Packages for the shell environment
  shellPackages = with pkgs; [
    btop
    direnv
    eza
    git
    mcfly
    ncdu
    ranger
    starship
    zsh
    zsh-autosuggestions
    zsh-autocomplete
    zsh-syntax-highlighting
  ];
in
pkgs.writeShellScriptBin "cole-shell" ''
  export SHRC="zsh"
  export PATH="${pkgs.lib.makeBinPath shellPackages}:${dotFilesPackages.scripts}/bin:$PATH"
  export STARSHIP_CONFIG="${dotFilesPackages.configs}/starship.toml"

  # Create temporary zshrc
  TMPDIR=$(mktemp -d)
  trap "rm -rf $TMPDIR" EXIT

  # Create .zshenv to prevent new-user wizard
  touch $TMPDIR/.zshenv

  cat > $TMPDIR/.zshrc << 'ZSHRC_EOF'
  # ncdu wrapper to use config from repo
  alias ncdu='XDG_CONFIG_HOME="${dotFilesPackages.configs}" ncdu'

  # Add Nix completions to fpath (modern nix commands)
  fpath=(${pkgs.nix}/share/zsh/site-functions $fpath)

  # Initialize completion system EARLY before loading aliases
  autoload -U compinit && compinit
  autoload -U colors && colors

  # Load completions
  if [[ -d "${dotFilesPackages.completions}" ]] && [[ -n "$(ls -A ${dotFilesPackages.completions} 2>/dev/null)" ]]; then
    for f in ${dotFilesPackages.completions}/*; do
      if [[ -f "$f" ]] && ! grep -q "^complete " "$f" 2>/dev/null; then
        source "$f"
      fi
    done
  fi

  # Load aliases (skip mcfly and starship)
  for f in ${dotFilesPackages.aliases}/*; do
    if [[ -f "$f" ]]; then
      fname="$(basename "$f")"
      case "$fname" in
        "mcfly"|"starship")
          ;;
        *)
          if ! grep -q "shopt\|complete " "$f" 2>/dev/null; then
            source "$f"
          fi
          ;;
      esac
    fi
  done

  # History configuration (must be before mcfly)
  HISTFILE=~/.zsh_history
  HISTSIZE=10000
  SAVEHIST=10000

  # Create history file if it doesn't exist
  [[ -f "$HISTFILE" ]] || touch "$HISTFILE"

  # Enable starship
  eval "$(${pkgs.starship}/bin/starship init zsh)"

  # Enable mcfly
  eval "$(${pkgs.mcfly}/bin/mcfly init zsh)"

  # Key bindings
  bindkey "^[[1;5C" forward-word
  bindkey "^[[1;5D" backward-word
  bindkey "^[[3~" delete-char
  bindkey "^[[H" beginning-of-line
  bindkey "^[[F" end-of-line

  # Load zsh plugins
  source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source ${pkgs.zsh-autocomplete}/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
  # Syntax highlighting must be loaded last
  source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

  # History options
  setopt HIST_IGNORE_DUPS
  setopt HIST_EXPIRE_DUPS_FIRST
  setopt EXTENDED_HISTORY
  setopt APPEND_HISTORY
  setopt SHARE_HISTORY

  ZSHRC_EOF

  export ZDOTDIR=$TMPDIR
  exec ${pkgs.zsh}/bin/zsh
''
