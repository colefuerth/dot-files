#!/bin/bash

# reverts terminal bringup to what it was pre-installation

if [ -d "$HOME/.zsh_aliases" ]; then
    if [ -f "$HOME/.zsh_aliases/.zsh_aliases" ]; then
        mv "$HOME/.zsh_aliases/.zsh_aliases" "$HOME/.zsh_aliases.bak"
    fi
    if [ -f "$HOME/.zsh_aliases/.zshrc" ]; then
        mv "$HOME/.zsh_aliases/.zshrc" "$HOME/.zshrc.bak"
    fi
    rm -rf "$HOME/.zsh_aliases"
    if [ -f "$HOME/.zsh_aliases.bak" ]; then
        mv "$HOME/.zsh_aliases.bak" "$HOME/.zsh_aliases"
    fi
    if [ -f "$HOME/.zshrc.bak" ]; then
        mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
    fi
fi

if [ -d "$HOME/.bash_aliases" ]; then
    if [ -f "$HOME/.bash_aliases/.bash_aliases" ]; then
        mv "$HOME/.bash_aliases/.bash_aliases" "$HOME/.bash_aliases.bak"
    fi
    if [ -f "$HOME/.bash_aliases/.bashrc" ]; then
        mv "$HOME/.bash_aliases/.bashrc" "$HOME/.bashrc.bak"
    fi
    rm -rf "$HOME/.bash_aliases"
    if [ -f "$HOME/.bash_aliases.bak" ]; then
        mv "$HOME/.bash_aliases.bak" "$HOME/.bash_aliases"
    fi
    if [ -f "$HOME/.bashrc.bak" ]; then
        mv "$HOME/.bashrc.bak" "$HOME/.bashrc"
    fi
fi
