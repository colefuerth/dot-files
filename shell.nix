{ pkgs, repoRoot }:

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
  ];
in
pkgs.writeShellScriptBin "cole-shell" ''
  export SHRC="zsh"
  export PATH="${pkgs.lib.makeBinPath shellPackages}:${repoRoot}/scripts:$PATH"
  export STARSHIP_CONFIG="${repoRoot}/.config/starship.toml"

  # Create temporary zshrc
  TMPDIR=$(mktemp -d)
  trap "rm -rf $TMPDIR" EXIT

  # Create .zshenv to prevent new-user wizard
  touch $TMPDIR/.zshenv

  cat > $TMPDIR/.zshrc << 'ZSHRC_EOF'
  # ncdu wrapper to use config from repo
  alias ncdu='XDG_CONFIG_HOME="${repoRoot}/.config" ncdu'

  # Load completions
  if [[ -d "${repoRoot}/completions" ]] && [[ -n "$(ls -A ${repoRoot}/completions 2>/dev/null)" ]]; then
    for f in ${repoRoot}/completions/*; do
      if [[ -f "$f" ]] && ! grep -q "^complete " "$f" 2>/dev/null; then
        source "$f"
      fi
    done
  fi

  # Load aliases (skip mcfly and starship)
  for f in ${repoRoot}/aliases/*; do
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

  # Completions
  autoload -U compinit && compinit
  autoload -U colors && colors

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
