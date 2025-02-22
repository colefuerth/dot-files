#!/bin/bash

[ ! -r "config.bash" ] && cp config.bash.example config.bash
. config.bash

[ "config.bash.example" -nt "config.bash" ] && echo "Your config.bash is out of date!! Please update it if there are any missing config options."

BIN="$HOME/.local/bin"
ALIASES_DIRS=(
    "$HOME/.zsh_aliases"
    "$HOME/.bash_aliases"
)

deploy() {
    SRC="$1"
    DEST="$2"
    if [ "$DEPLOYMENT_METHOD" = "softlink" ]; then
        [ ! -e "$DEST" ] && ln -s "$SRC" "$DEST"
    elif [ "$DEPLOYMENT_METHOD" = "copy" ]; then
        cp --update "$SRC" "$DEST"
    else
        echo "SD Scripts Error: Invalid DEPLOYMENT_METHOD \"$DEPLOYMENT_METHOD\""
        exit 1
    fi
}

if git remote update -p > /dev/null && git status -uno | grep -q 'Your branch is behind'; then
    echo "dot-files has an update!"
    git pull
fi

for ALIASES in "${ALIASES_DIRS[@]}"; do
    if [ -d $ALIASES ]; then
        for file in aliases/*; do
            deploy "$PWD/$file" "$ALIASES/$(basename "$file")"
        done
        [ ! $EZA ] && rm -f $ALIASES/exa
        [ ! $INSTALL_STARSHIP ] && rm -f $ALIASES/starship
        [ ! $MCFLY ] && rm -f $ALIASES/mcfly
        [ ! $INSTALL_CCACHE ] && rm -f $ALIASES/ccache
        true  # clear last command output
    fi
done

if [ -d $BIN ]; then
    for file in scripts/*; do
        deploy "$PWD/$file" "$BIN/$(basename "$file")"
    done
fi
