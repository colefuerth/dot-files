#!/bin/bash

BIN="$HOME/.local/bin"
ALIASES="$HOME/.zsh_aliases"

if git remote update -p > /dev/null && git status -uno | grep -q 'Your branch is behind'; then
    echo "dot-files has an update!"
    git pull
fi

mkdir -p "$ALIASES"

for file in aliases/*; do
    destination="$ALIASES/$(basename "$file")"
    if [ ! -e "$destination" ]; then
        ln -s "$PWD/$file" "$destination"
    fi
done
