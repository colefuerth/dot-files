#!/bin/bash

[ ! -r "config.bash" ] && cp config.bash.example config.bash
. config.bash

BIN="$HOME/.local/bin"
ALIASES_DIRS=(
    "$HOME/.zsh_aliases"
    "$HOME/.bash_aliases"
)

if git remote update -p > /dev/null && git status -uno | grep -q 'Your branch is behind'; then
    echo "dot-files has an update!"
    git pull
fi

for ALIASES in "${ALIASES_DIRS[@]}"; do
    if [ -d $ALIASES ]; then
        for file in aliases/*; do
            destination="$ALIASES/$(basename "$file")"
            if [ ! -e "$destination" ]; then
                ln -s "$PWD/$file" "$destination"
            fi
        done
    fi
done
