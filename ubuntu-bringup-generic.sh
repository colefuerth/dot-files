# POP!_OS 22.04 LTS BRINGUP

set -x

# SETTINGS
SETUP_SSH=true
SETUP_DIALOUT=true
INSTALL_STARSHIP=true  # install starship prompt
INSTALL_ZSH=true       # install zsh & set as default shell
INSTALL_TOOLS=true     # a set of tools that I like to use (ranger, ncdu, htop, 7z, etc)
SETUP_GIT=true         # performs most of the git setup for you
SETUP_WELCOME_MSG=true # sets up a welcome message for the terminal
SETUP_BASH=true        # sets up bashrcm with my aliases etc
INSTALL_CCACHE=true    # sets up CCACHE
CCACHE_ALIASES=true    # set ccache paths

BASE=$(pwd)
MKDIR="mkdir -p"

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
    $MKDIR $HOME/.ssh
    touch $HOME/.ssh/authorized_keys
    cp config $HOME/.ssh/config
fi

# define a function for aliases to be added to .bashrc or .zshrc
function add_aliases() {
    $MKDIR "$1"_aliases
    ALIASES="$HOME"/"$1"_aliases

    # generic aliases on every system
    ln -s aliases/aliases $ALIASES/aliases

    # flagged aliases
    $INSTALL_TOOLS && ln -s aliases/tools $ALIASES/tools
    $CCACHE_ALIASES && ln -s aliases/ccache $ALIASES/ccache
    $INSTALL_STARSHIP && ln -s aliases/starship $ALIASES/starship
}

if $INSTALL_ZSH; then
    # zsh
    sudo apt install -y zsh

    # oh my zsh
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    chsh -s $(which zsh)

    # .zshrc setup
    cp zshrc $HOME/.zshrc
    if [ ! -e "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    else
        cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && git pull
    fi

    # aliases and evals, as a list
    # (generated at runtime since this varies depending on flags)
    add_aliases ".zshrc"
fi

if $INSTALL_TOOLS; then
    cd /tmp
    # my tools
    sudo apt install -y ranger python3 python2 python3-pip python3-venv screen curl
    /usr/bin/python3 -m pip install --user --upgrade pip
    /usr/bin/python3 -m pip install --user virtualenv
    /usr/bin/python3 -m pip install --user numpy pandas matplotlib jupyterlab

    # ncdu static binary 2.3
    curl -fsSL https://dev.yorhel.nl/download/ncdu-2.3-linux-x86_64.tar.gz -o /tmp/ncdu.tar.gz
    tar -xvf /tmp/ncdu.tar.gz -C /tmp
    sudo cp /tmp/ncdu /usr/bin/ncdu
    sudo chmod +x /usr/bin/ncdu
    rm /tmp/ncdu.tar.gz

    # 7z static binary 23.01
    curl -fsSL https://7-zip.org/a/7z2301-linux-x64.tar.xz -o /tmp/7z.tar.xz
    mkdir /tmp/7z
    tar -xvf /tmp/7z.tar.xz -C /tmp/7z
    sudo cp /tmp/7z/7zz /usr/local/bin/7zz
    sudo ln -s /usr/local/bin/7zz /usr/local/bin/7z
    rm -rf /tmp/7z

    # htop static binary 3.2.2
    curl -fsSL http://ftp.us.debian.org/debian/pool/main/h/htop/htop_3.2.2-2_amd64.deb -o /tmp/htop.deb
    sudo dpkg -i /tmp/htop.deb
    rm /tmp/htop.deb

    # rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

    # mcfly
    sudo curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sh -s -- --git cantino/mcfly

    # advanced copy/move
    cd /tmp
    curl https://raw.githubusercontent.com/jarun/advcpmv/master/install.sh --create-dirs -o ./advcpmv/install.sh && (cd advcpmv && sh install.sh)
    sudo mv ./advcpmv/advcp /usr/local/bin/
    sudo mv ./advcpmv/advmv /usr/local/bin/
    rm -rf ./advcpmv

    # clipboard
    sudo apt install libx11-dev libwayland-dev cmake
    cd /tmp
    git clone https://github.com/Slackadays/Clipboard
    cd Clipboard/build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    cmake --build . -j 12
    sudo cmake --install .
    cd && rm -rf /tmp/Clipboard

fi

cd $BASE

if $INSTALL_CCACHE; then
    curl -fsSL https://github.com/ccache/ccache/releases/download/v4.8.3/ccache-4.8.3-linux-x86_64.tar.xz \
        -o /tmp/ccache.tar.xz
    tar -xvf /tmp/ccache.tar.xz -C /tmp
    sudo cp /tmp/ccache-4.8.3-linux-x86_64/ccache /usr/local/bin/ccache
    rm -rf /tmp/ccache-4.8.3-linux-x86_64 /tmp/ccache-4.8.3-linux-x86_64.tar.xz
fi

if $INSTALL_STARSHIP; then
    # OPTIONAL: install starship prompt, and set it up with my config (you can change this lol)
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
    mkdir $HOME/.config -p
    curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/starship.toml \
        -o $HOME/.config/starship.toml
fi

# .bashrc
if $SETUP_BASH; then
    echo "eval \"\$(starship init bash)\"" >>$HOME/.bashrc
    add_aliases ".bashrc"
fi

# setup verbose boot
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
if $SETUP_GIT; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    echo "** copy this into github ----------------------------------"
    more ~/.ssh/id_rsa.pub
    echo "----------------------------------------------------------- **"
fi

echo
echo "** you should generate a keypair on your host and copy the public key into $(~/.ssh/authorized_keys) on the vm **"
