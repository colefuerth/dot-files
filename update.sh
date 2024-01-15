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
            if [ "$DEPLOYMENT_METHOD" = "softlink" ]; then
                [ ! -e "$destination" ] && ln -s "$PWD/$file" "$destination"
            elif [ "$DEPLOYMENT_METHOD" = "copy" ]; then
                cp --update "$PWD/$file" "$destination"
            else
                echo "SD Scripts Error: Invalid DEPLOYMENT_METHOD, not deploying aliases."
                break
            fi
        done
    fi
done
