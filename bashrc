#!/usr/bin/bash

SCRIPTS_DIR="$HOME/dot-files"
if [ ! -z SCRIPTS_DIR ] && [ -r "$SCRIPTS_DIR/config.bash" ] && grep -q "AUTO_UPDATE=true" "$SCRIPTS_DIR/config.bash"; then
    (cd $SCRIPTS_DIR && ./update.sh)
fi

SHRC="bash"

# Load Zsh alias files from ~/zsh_aliases/
for file in $HOME/.bash_aliases/*; do
    source "$file"
done
