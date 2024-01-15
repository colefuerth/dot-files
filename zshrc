#!/usr/bin/zsh

# for those wondering: your old zshrc file is under "~/.zsh_aliases/.zshrc"

ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME=""

# Plugins
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# auto updating only happens if the scripts_dir exists, the config is set, and auto_update has been set to true
SCRIPTS_DIR="$HOME/dot-files"
if [ ! -z SCRIPTS_DIR ] && [ -r "$SCRIPTS_DIR/config.bash" ] && grep -q "AUTO_UPDATE=true" "$SCRIPTS_DIR/config.bash"; then
    (cd $SCRIPTS_DIR && ./update.sh)
fi

SHRC="zsh"

# Load Zsh alias files from ~/zsh_aliases/
for file in $HOME/.zsh_aliases/*; do
    source "$file"
done
