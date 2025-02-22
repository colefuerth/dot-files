#!/bin/bash

[ ! -f "config.bash" ] && cp -v config.bash.example config.bash && \
    echo "*** \"config.bash\" NOT FOUND!! Using the default \"config.bash.example\" instead..." && \
    echo "PRESS CRTL+C TO STOP INSTALLING IF YOU WANT TO CONFIGURE FIRST" && \
    echo "Continuing in 10 seconds..." && sleep 10
. config.bash

deploy() {
    SRC="$1"
    DEST="$2"
    if [ "$DEPLOYMENT_METHOD" = "softlink" ]; then
        ln -s "$SRC" "$DEST"
    elif [ "$DEPLOYMENT_METHOD" = "copy" ]; then
        cp --update "$SRC" "$DEST"
    else
        echo "SD Scripts Error: Invalid DEPLOYMENT_METHOD \"$DEPLOYMENT_METHOD\""
        exit 1
    fi
}

BASE=$(pwd)

# add the local bin path to PATH to mute a bunch of pip records
PATH="$PATH:$HOME/.local/bin"

# update packages
sudo apt update
sudo add-apt-repository universe -y
sudo apt update
sudo apt upgrade -y

# get ssh set up first
if $SETUP_SSH; then
    sudo apt install -y openssh-server
    sudo ufw allow ssh
    sudo systemctl enable ssh
    mkdir -p $HOME/.ssh
    touch $HOME/.ssh/authorized_keys
fi

if $IS_VM; then
    sudo apt install open-vm-tools -y
fi

if $INSTALL_ZSH; then
    # zsh
    sudo apt install -y zsh
fi

if $SETUP_ZSH; then

    # oh my zsh and zsh-autosuggestions
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

    if [ ! -e "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    else
        cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && git pull
    fi

    # .zsh_aliases setup

    if [ -f "$HOME/.zsh_aliases" ]; then
        mv "$HOME/.zsh_aliases" "$HOME/zsh_aliases"
        mkdir -p "$HOME/.zsh_aliases"
        mv "$HOME/zsh_aliases" "$HOME/.zsh_aliases/zsh_aliases"
    else
        mkdir -p "$HOME/.zsh_aliases"
    fi

    # .zshrc setup
    if [ -e "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$HOME/.zsh_aliases/zshrc"
    fi
    cp dot-rc/zshrc $HOME/.zshrc
    sed -i "s|^SCRIPTS_DIR=\".*\"|SCRIPTS_DIR=\"$BASE\"|" $HOME/.zshrc

fi

if $INSTALL_FISH; then
    sudo apt-add-repository -y ppa:fish-shell/release-3
    sudo apt update
    sudo apt install -y fish
fi

# if $SETUP_FISH; then

#     # .fish_aliases setup

#     if [ -f "$HOME/.fish_aliases" ]; then
#         mv "$HOME/.fish_aliases" "$HOME/fish_aliases"
#         mkdir -p "$HOME/.fish_aliases"
#         mv "$HOME/fish_aliases" "$HOME/.fish_aliases/fish_aliases"
#     else
#         mkdir -p "$HOME/.fish_aliases"
#     fi

#     # .fishrc setup
#     if [ -e "$HOME/.fishrc" ]; then
#         mv "$HOME/.fishrc" "$HOME/.fish_aliases/.fishrc"
#     fi
#     cp dot-rc/fishrc $HOME/.fishrc
#     sed -i "s|^SCRIPTS_DIR=\".*\"|SCRIPTS_DIR=\"$BASE\"|" $HOME/.fishrc

# fi

if $SETUP_BASH; then
    # .bash_aliases setup
    if [ -f "$HOME/.bash_aliases" ]; then
        mv "$HOME/.bash_aliases" "$HOME/bash_aliases"
        mkdir -p "$HOME/.bash_aliases"
        mv "$HOME/bash_aliases" "$HOME/.bash_aliases/bash_aliases"
    else
        mkdir -p "$HOME/.bash_aliases"
    fi

    # .bashrc setup
    if [ -e "$HOME/.bashrc" ]; then
        mv "$HOME/.bashrc" "$HOME/.bash_aliases/.bashrc"
    fi
    cp dot-rc/bashrc $HOME/.bashrc
    sed -i "s|^SCRIPTS_DIR=\".*\"|SCRIPTS_DIR=\"$BASE\"|" $HOME/.bashrc
fi

if $INSTALL_TOOLS; then
    cd /tmp
    sudo apt --fix-broken install -y && sudo apt autoremove -y

    if $PYTHON; then
        sudo apt install -y python3 python3-pip
        /usr/bin/python3 -m pip install --user --upgrade pip
        if $PYTHON_EXT; then
            sudo apt install -y python3-venv python3-virtualenv python3-numpy
        fi
    fi

    if [ -n "$MORE_TOOLS" ]; then
        sudo apt install -y $MORE_TOOLS
    fi

    if [ $NCDU ] &> /dev/null; then
        # ncdu static binary 2.7
        curl -fsSL https://dev.yorhel.nl/download/ncdu-2.7-linux-x86_64.tar.gz -o /tmp/ncdu.tar.gz
        tar -xvf /tmp/ncdu.tar.gz -C /tmp
        sudo chmod +x /tmp/ncdu
        sudo mv /tmp/ncdu /usr/local/bin/ncdu
        rm /tmp/ncdu.tar.gz

        # also copy my default config
        mkdir -p $HOME/.config/ncdu && \
        deploy $BASE/.config/ncdu/config $HOME/.config/ncdu/config
    fi

    if [ $INSTALL_7Z ] && ! command -v 7z &> /dev/null; then
        # 7z static binary 23.01
        curl -fsSL https://7-zip.org/a/7z2409-linux-x64.tar.xz -o /tmp/7z.tar.xz
        mkdir /tmp/7z
        tar -xf /tmp/7z.tar.xz -C /tmp/7z
        sudo mv /tmp/7z/7zz /usr/local/bin/7zz
        rm -rf /tmp/7z /tmp/7z.tar.xz
    fi

    if [ $HTOP ] && ! command -v htop &> /dev/null; then
        # htop static binary 3.2.2
        curl -fsSL https://github.com/htop-dev/htop/releases/download/3.3.0/htop-3.3.0.tar.xz -o /tmp/htop.tar.xz
        sudo apt install -y libncursesw5-dev autotools-dev autoconf automake build-essential libsensors-dev
        tar -xf /tmp/htop.tar.xz -C /tmp
        (cd /tmp/htop-3.3.0 && ./autogen.sh && ./configure --enable-static && sudo make install)
        rm -rf /tmp/htop-3.3.0 /tmp/htop.tar.xz
    fi

    if [ $BTOP ] && ! command -v btop &> /dev/null; then
        # btop static binary latest (last updated at btop 1.3.2, apt btop is at 1.2.3)
        sudo apt install -y coreutils sed git build-essential gcc-11 g++-11 lowdown
        git clone https://github.com/aristocratos/btop.git /tmp/btop
        (cd /tmp/btop && make -j$(nproc) && sudo make install && sudo make setuid)
        rm -rf /tmp/btop

        # also copy my default config
        mkdir -p $HOME/.config/btop && \
        cp $BASE/.config/btop/btop.conf $HOME/.config/btop/btop.conf
    fi

    if [ $RUST ] && ! command -v rustc &> /dev/null; then
        # rust
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi

    if [ $EZA || $RMZ || $CPZ ]; then
        CMD=""
        [ $EZA ] && CMD="$CMD eza"
        [ $RMZ ] && CMD="$CMD rmz"
        [ $CPZ ] && CMD="$CMD cpz"
        cargo install $CMD
    fi

    if [ $MCFLY ] && ! command -v mcfly &> /dev/null; then
        # mcfly
        sudo curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sudo sh -s -- --git cantino/mcfly
    fi

    if [ $ADVCPMV ] && ! command -v advcp &> /dev/null; then
        # advanced copy/move
        curl https://raw.githubusercontent.com/jarun/advcpmv/master/install.sh --create-dirs -o ./advcpmv/install.sh && (cd advcpmv && sh install.sh)
        sudo mv ./advcpmv/advcp /usr/local/bin/
        sudo mv ./advcpmv/advmv /usr/local/bin/
        rm -rf ./advcpmv
    fi

    if [ $CLIPBOARD ] && ! command -v cb &> /dev/null; then
        curl -fsSL https://github.com/Slackadays/Clipboard/releases/download/0.10.0/clipboard-linux-amd64.zip -o /tmp/clipboard.zip
        mkdir -p /tmp/clipboard
        unzip -d /tmp/clipboard /tmp/clipboard.zip
        sudo chmod +x /tmp/clipboard/bin/cb
        sudo cp -rv /tmp/clipboard/* /usr
        rm -rf /tmp/clipboard /tmp/clipboard.zip
    fi
fi

cd $BASE

if [ $INSTALL_CCACHE ] && ! command -v ccache &> /dev/null; then
    curl -fsSL https://github.com/ccache/ccache/releases/download/v4.8.3/ccache-4.8.3-linux-x86_64.tar.xz \
        -o /tmp/ccache.tar.xz
    tar -xvf /tmp/ccache.tar.xz -C /tmp
    sudo cp /tmp/ccache-4.8.3-linux-x86_64/ccache /usr/local/bin/ccache
    rm -rf /tmp/ccache-4.8.3-linux-x86_64 /tmp/ccache-4.8.3-linux-x86_64.tar.xz
fi

if [ $INSTALL_STARSHIP ] && ! command -v starship &> /dev/null; then
    # OPTIONAL: install starship prompt, and set it up with my config (you can change this lol)
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
    # also copy my default config
    mkdir -p $HOME/.config && deploy $BASE/.config/starship.toml $HOME/.config/starship.toml
fi

# setup verbose boot in pop!_os
# sudo apt install -y kernelstub
# sudo kernelstub --delete-options "quiet systemd.show_status=false splash"
# sudo kernelstub --add-options "systemd.show_status=true"

if $SETUP_WELCOME_MSG; then
    # welcome messages
    sudo apt install -y inxi neofetch
    sudo chmod -x /etc/update-motd.d/*
    sudo curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/10-welcome \
        -o /etc/update-motd.d/01-welcome
    sudo chmod +x /etc/update-motd.d/01-welcome
fi

if $SETUP_GIT; then
    # git config
    # get the user's name and email from cli
    EMAIL=""
    while [ -z "$EMAIL" ]; do
        read -p "Enter your email for git: " EMAIL
    done
    NAME=""
    while [ -z "$NAME" ]; do
        read -p "Enter your name for git: " NAME
    done
    git config --global user.email "$EMAIL"
    git config --global user.name "$NAME"
    git config --global core.editor "nano"
    git config --global pull.rebase false
    git config --global color.ui true
    sudo bash -c "echo 'fs.inotify.max_user_watches=524288' >> /etc/sysctl.conf"
    sudo sysctl -p
fi

# need to add user to dialout group for serial access
if $SETUP_DIALOUT; then
    sudo usermod -a -G dialout $USER
fi

# at the end we should run an update and autoremove in case anything was missed
sudo apt update && sudo apt autoremove -y

# need to ssh-keygen a new keypair for bitbucket
if $SETUP_GIT && [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    echo "** copy this into github ----------------------------------"
    more ~/.ssh/id_rsa.pub
    echo "----------------------------------------------------------- **"
fi

# set some final settings
chsh -s $(which $DEFAULT_SHELL)

bash update.sh

echo
echo
echo
echo "** you should generate a keypair on your host and copy the public key into ~/.ssh/authorized_keys on the vm **"
