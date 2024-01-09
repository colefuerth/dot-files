#!/usr/bin/zsh

ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME=""

# Plugins
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

SCRIPTS_DIR="$HOME/dot-files"  # location of scripts and/or dot-files, set this to auto update
if [ ! -z SCRIPTS_DIR ]; then
    sh -c "cd $SCRIPTS_DIR && bash update.sh"
fi

# Load Zsh alias files from ~/zsh_aliases/
for file in $HOME/.zsh_aliases/*; do
    [ -r "$file" ] && source "$file"
done

if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi
