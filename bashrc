#!/usr/bin/bash

SCRIPTS_DIR="$HOME/dot-files"  # location of scripts and/or dot-files, set this to auto update
if [ ! -z SCRIPTS_DIR ]; then
    sh -c "cd $SCRIPTS_DIR && bash update.sh"
fi

# Load Zsh alias files from ~/zsh_aliases/
for file in $HOME/.bash_aliases/*; do
    [ -r "$file" ] && source "$file"
done
