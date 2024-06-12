#!/bin/bash

[ ! -f "config.bash" ] && cp -v config.bash.example config.bash && \
    echo "*** \"config.bash\" NOT FOUND!! Using the default \"config.bash.example\" instead..." && \
    echo "PRESS CRTL+C TO STOP INSTALLING IF YOU WANT TO CONFIGURE FIRST" && \
    echo "Continuing in 10 seconds..." && sleep 10
. config.bash

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
        mv "$HOME/.zshrc" "$HOME/.zsh_aliases/.zshrc"
    fi
    cp zshrc $HOME/.zshrc
    sed -i "s|^SCRIPTS_DIR=\".*\"|SCRIPTS_DIR=\"$BASE\"|" $HOME/.zshrc

fi

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
    cp bashrc $HOME/.bashrc
    sed -i "s|^SCRIPTS_DIR=\".*\"|SCRIPTS_DIR=\"$BASE\"|" $HOME/.bashrc
fi

if $INSTALL_TOOLS; then
    cd /tmp
    sudo apt --fix-broken install -y && sudo apt autoremove -y

    if $PYTHON; then
        sudo apt install -y python3 python2 python3-pip
        /usr/bin/python3 -m pip install --user --upgrade pip
        if $PYTHON_EXT; then
            sudo apt insatll python3-venv
            /usr/bin/python3 -m pip install --user virtualenv
            /usr/bin/python3 -m pip install --user numpy pandas matplotlib jupyterlab
        fi
    fi

    if [ -n "$MORE_TOOLS" ]; then
        sudo apt install $MORE_TOOLS
    fi

    if [ $NCDU ] && ! command -v ncdu &> /dev/null; then
        # ncdu static binary 2.3
        curl -fsSL https://dev.yorhel.nl/download/ncdu-2.3-linux-x86_64.tar.gz -o /tmp/ncdu.tar.gz
        tar -xvf /tmp/ncdu.tar.gz -C /tmp
        sudo cp /tmp/ncdu /usr/local/bin/ncdu
        sudo chmod +x /usr/local/bin/ncdu
        rm /tmp/ncdu.tar.gz
    fi

    if [ $INSTALL_7Z ] && ! command -v 7z &> /dev/null; then
        # 7z static binary 23.01
        curl -fsSL https://7-zip.org/a/7z2301-linux-x64.tar.xz -o /tmp/7z.tar.xz
        mkdir /tmp/7z
        tar -xvf /tmp/7z.tar.xz -C /tmp/7z
        sudo cp /tmp/7z/7zz /usr/local/bin/7zz
        sudo ln -s /usr/local/bin/7zz /usr/local/bin/7z
        rm -rf /tmp/7z
    fi

    if [ $HTOP ] && ! command -v htop &> /dev/null; then
        # htop static binary 3.2.2
        curl -fsSL http://ftp.us.debian.org/debian/pool/main/h/htop/htop_3.2.2-2_amd64.deb -o /tmp/htop.deb
        sudo dpkg -i /tmp/htop.deb
        rm /tmp/htop.deb
    fi

    if [ $BTOP ] && ! command -v btop &> /dev/null; then
        # htop static binary 3.2.2
        cd /tmp
        sudo apt install -y coreutils sed git build-essential gcc-11 g++-11 lowdown
        curl -fsSL https://github.com/aristocratos/btop/releases/download/v1.3.2/btop-x86_64-linux-musl.tbz -o /tmp/btop.tbz
        tar -xjf btop.tbz
        cd btop
        # use "make install PREFIX=/target/dir" to set target, default: /usr/local
        # only use "sudo" when installing to a NON user owned directory
        sudo make install
        # run after make install and use same PREFIX if any was used at install
        # set SU_USER and SU_GROUP to select user and group, default is root:root
        sudo make setuid
        rm -rf /tmp/btop /tmp/btop.tbz
        cd /tmp
    fi

    if [ $RUST ] && ! command -v rustc &> /dev/null; then
        # rust
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
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
        curl -fsSL https://github.com/Slackadays/Clipboard/releases/download/0.9.0.1/clipboard-linux-amd64.zip -o /tmp/clipboard.zip
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
    mkdir -p $HOME/.config
    curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/starship.toml \
        -o $HOME/.config/starship.toml
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
