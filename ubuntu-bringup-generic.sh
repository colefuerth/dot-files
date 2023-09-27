# POP!_OS 22.04 LTS BRINGUP

set -x

# SETTINGS
INSTALL_STARSHIP=true       # install starship prompt
INSTALL_ZSH=true           # install zsh & set as default shell
INSTALL_QEMU=true           # install qemu dependencies for building SD's qemu
INSTALL_NPM=true
INSTALL_SD=true
INSTALL_TOOLS=true          # a set of tools that I like to use (ranger, ncdu, htop, 7z, etc)
SETUP_GIT=true              # performs most of the git setup for you
SETUP_WELCOME_MSG=true      # sets up a welcome message for the terminal
SETUP_BASH=true             # sets up bashrcm with my aliases etc
INSTALL_CCACHE=true         # sets up CCACHE
CCACHE_ALIASES=true         # masquerade ccache as g++ and gcc, so it is on for *everything*

# update packages
sudo apt update
sudo add-apt-repository universe -y
sudo apt update
sudo apt upgrade -y

# get ssh set up first
sudo apt install -y openssh-server
sudo ufw allow ssh
sudo systemctl enable ssh
mkdir -p /home/$USER/.ssh
touch /home/$USER/.ssh/authorized_keys

# need node.js 18, npm 9, and yarn (bc why not) (since this is a dependency for some stuff later it needs to install first)
if $INSTALL_NPM; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - &&\
    sudo apt-get install -y nodejs
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update && sudo apt-get install yarn -y
fi

if $INSTALL_SD; then
    # openwrt dependencies
    sudo apt install -y build-essential clang flex bison g++ gawk git rsync unzip file wget gettext gcc-multilib g++-multilib libncurses-dev libssl-dev python3-distutils zlib1g-dev
    # satcom dependencies
    sudo apt install -y npm minicom python2 libncurses5 libncurses5-dev libncurses6 libncurses-dev ncurses-base zlib1g-dev zlib1g libelf-dev
fi

if $INSTALL_TOOLS; then
    # my tools
    sudo apt install -y ranger python3 python3-pip python3-venv screen curl
    /usr/bin/python3 -m pip install --user --upgrade pip
    /usr/bin/python3 -m pip install --user virtualenv
    # /usr/bin/python3 -m pip install --user numpy pandas matplotlib jupyterlab

    # ncdu static binary 2.3
    curl -fsSL https://dev.yorhel.nl/download/ncdu-2.3-linux-x86_64.tar.gz -o /tmp/ncdu.tar.gz
    tar -xvf /tmp/ncdu.tar.gz -C /tmp
    sudo mv /tmp/ncdu /usr/bin/ncdu
    sudo chmod +x /usr/bin/ncdu
    rm /tmp/ncdu.tar.gz

    # 7z static binary 23.01
    curl -fsSL https://7-zip.org/a/7z2301-linux-x64.tar.xz -o /tmp/7z.tar.xz
    mkdir /tmp/7z
    tar -xvf /tmp/7z.tar.xz -C /tmp/7z
    sudo mv /tmp/7z/7zz /usr/local/bin/7zz
    rm -rf /tmp/7z

    # htop static binary 3.2.2
    curl -fsSL http://ftp.us.debian.org/debian/pool/main/h/htop/htop_3.2.2-2_amd64.deb -o /tmp/htop.deb
    sudo dpkg -i /tmp/htop.deb
    rm /tmp/htop.deb

    # rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

if $INSTALL_CCACHE; then
    curl -fsSL https://github.com/ccache/ccache/releases/download/v4.8.3/ccache-4.8.3-linux-x86_64.tar.xz -o /tmp/ccache.tar.xz
    tar -xvf /tmp/ccache.tar.xz -C /tmp
    sudo cp /tmp/ccache-4.8.3-linux-x86_64/ccache /usr/local/bin/ccache
    rm -rf /tmp/ccache-4.8.3-linux-x86_64 /tmp/ccache-4.8.3-linux-x86_64.tar.xz
    # if $CCACHE_ALIASES; then
    #     # sudo rm -f /usr/local/bin/gcc /usr/local/bin/g++
    #     # sudo ln -s /usr/local/bin/ccache /usr/local/bin/gcc
    #     # sudo ln -s /usr/local/bin/ccache /usr/local/bin/g++
    # fi
fi

if $INSTALL_STARSHIP; then
    # OPTIONAL: install starship prompt, and set it up with my config (you can change this lol)
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
    mkdir /home/$USER/.config -p
    curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/starship.toml -o /home/$USER/.config/starship.toml
fi

# define a function for aliases to be added to .bashrc or .zshrc
function add_aliases() {
    echo "alias py='/usr/bin/python3'" >> /home/$USER/$1
    echo "alias pip='/usr/bin/python3 -m pip'" >> /home/$USER/$1
    echo "alias pip3='/usr/bin/python3 -m pip'" >> /home/$USER/$1
    echo "alias ll='ls -alh'" >> /home/$USER/$1
    echo "PATH=\$PATH:/home/$USER/.local/bin" >> /home/$USER/$1
    if $INSTALL_TOOLS; then
        echo "alias 7z='/usr/local/bin/7zz'" >> /home/$USER/$1
        echo "PATH=\$PATH:/home/$USER/.cargo/bin" >> /home/$USER/$1
    fi
    if $INSTALL_CCACHE; then
        echo "export CCACHE_DIR=/home/$USER/.ccache" >> /home/$USER/$1
        echo "export CCACHE_TEMPDIR=/home/$USER/.ccache" >> /home/$USER/$1
    fi
    if $INSTALL_SD; then
        echo "alias sdgu='./sda/scripts/git-feeds-check.sh update'" >> /home/$USER/$1
        echo "alias sdgp='./sda/scripts/git-feeds-check.sh pull'" >> /home/$USER/$1
        echo "alias sdcp='./sda/scripts/compile_package.sh'" >> /home/$USER/$1
        echo "alias sdfc='./sda/scripts/full-clean.sh'" >> /home/$USER/$1
        echo "alias sdba='./sda/scripts/build_all.sh'" >> /home/$USER/$1
        echo "alias sdmm='make menuconfig'" >> /home/$USER/$1
        echo "alias sdmk='make -j$(nproc)'" >> /home/$USER/$1
        if $CCACHE_ALIASES; then
            echo "alias gcc='ccache gcc'" >> /home/$USER/$1
            echo "alias g++='ccache g++'" >> /home/$USER/$1
        fi
    fi
}

if $INSTALL_ZSH; then
    # zsh
    sudo apt install -y zsh
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    chsh -s $(which zsh)


    # .zshrc
    touch /home/$USER/.zshrc
    echo 'ZSH="/home/$USER/.oh-my-zsh"

    # Theme
    ZSH_THEME=""

    # Plugins
    plugins=(git zsh-autosuggestions)
    source $ZSH/oh-my-zsh.sh

    # Star Ship
    eval "$(starship init zsh)"
    ' >> /home/$USER/.zshrc
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # aliases, as a list
    add_aliases ".zshrc"
fi

# .bashrc
if $SETUP_BASH; then
    echo "eval \"\$(starship init bash)\"" >> /home/$USER/.bashrc
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
    sudo curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/10-welcome -o /etc/update-motd.d/01-welcome
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
    sudo bash -c "echo 'fs.inotify.max_user_watches=524288' >> /etc/sysctl.conf"
    sudo sysctl -p
fi

# need to add user to dialout group for serial access
sudo usermod -a -G dialout $USER

if $SETUP_QEMU; then
    # qemu runtime for general emulation
    sudo apt install -y qemu-system-arm qemu-efi-aarch64 qemu-utils
fi

if $SETUP_QEMU && $INSTALL_SD; then
    # qemu dependencies for compiling our fork of qemu
    sudo apt install -y pkg-config autoconf automake libpng-dev libjpeg-dev libmodplug-dev libode-dev git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build git-email libaio-dev libbluetooth-dev libcapstone-dev libbrlapi-dev libbz2-dev libcap-ng-dev libcurl4-gnutls-dev libgtk-3-dev libibverbs-dev libjpeg8-dev libncurses5-dev libnuma-dev librbd-dev librdmacm-dev libsasl2-dev libsdl2-dev libseccomp-dev libsnappy-dev libssh-dev libvde-dev libvdeplug-dev libvte-2.91-dev libxen-dev liblzo2-dev valgrind xfslibs-dev libnfs-dev libiscsi-dev
fi

# at the end we should run an update and autoremove in case anything was missed
sudo apt update
sudo apt autoremove -y

# need to ssh-keygen a new keypair for bitbucket
if $SETUP_GIT; then
    ssh-keygen -t rsa -b 4096 -C "sd-vm-popos" -f ~/.ssh/id_rsa
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    echo "** copy this into github ----------------------------------"
    more ~/.ssh/id_rsa.pub
    echo "----------------------------------------------------------- **"
fi

echo
echo "** you should generate a keypair on your host and copy the public key into `~/.ssh/authorized_keys` on the vm **"