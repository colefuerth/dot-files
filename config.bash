#!/bin/bash

SETUP_SSH=true
SETUP_DIALOUT=true
INSTALL_STARSHIP=true  # install starship prompt
INSTALL_ZSH=true       # install zsh & set as default shell
INSTALL_TOOLS=true     # a set of tools that I like to use (more specific configuration below)
SETUP_GIT=true         # performs most of the git setup for you
SETUP_WELCOME_MSG=true # sets up a welcome message for the terminal
SETUP_BASH=false        # sets up bashrc with my aliases etc
INSTALL_CCACHE=true    # installs ccache binaries and sets up PATH

# TOOLS SUBCONFIG (optional extra tools)
# note: does nothing if INSTALL_TOOLS is set to false
NCDU=true
INSTALL_7Z=true
HTOP=true
RUST=false
MCFLY=true
ADVCPMV=true
CLIPBOARD=true
