# POP!_OS 22.04 LTS BRINGUP

# update packages
sudo apt update
sudo add-apt-repository universe -y
sudo apt update
sudo apt upgrade -y

# get ssh set up first
sudo apt install -y openssh-server
sudo ufw allow ssh
sudo systemctl enable ssh
mkdir -p /home/cole/.ssh
touch /home/cole/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDisLh79Jk2nTadYODDbrKBr194TliCwE5uiXbKW8T/bfi41qE7j2i9CnX1HGSIJUQBB2iW3luLMlmkO9jd2hsBx1XHaikx1aakGC/ItwBAzJC/b0w/bT4+fLHcjbHuD2ziJ7XU+aZS9U3uKOJ5wwIPK7o4UaaCnqMeB0q4+SaR6I2M25ov8VyBwCxvzew4xDKQ+eHHRpBu1iER19NMJDQu/z1J7JeTl4tdBPcPeq5pIceZvLsIeqAe/XBImoP4uUhaYuqWyL0YtY0u2XqZUNK9/no7U4BD1fTs2ssqdKXCgc/h8wvI4D5QNznC7+jiuUoFWONbpyJD9rnobGbwIvBbdFeT/5WaynAcjewl/RLhP5ppiAijXr5fmdGQKB0fv+/3kruZZbWE9fAcUWy0oagLh9ySLPgcJC7E+EtRwqjTbmUVUuZ73W+3xhdxKv1TyUJVyRgzX/2Of7cDPQJL0CK49hleodb5O9aGbns4QecxMJbOW2IjZj90jN2EaAWYjCc= cfuerth@J9VHFY3-5527-LT" >> /home/cole/.ssh/authorized_keys

# need node.js 18, npm 9, and yarn (bc why not) (since this is a dependency for some stuff later it needs to install first)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - &&\
sudo apt-get install -y nodejs
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install yarn -y

# openwrt dependencies
sudo apt install -y build-essential clang flex bison g++ gawk git rsync unzip file wget gettext gcc-multilib g++-multilib libncurses-dev libssl-dev python3-distutils zlib1g-dev

# satcom dependencies
sudo apt install -y npm minicom python2 libncurses5 libncurses5-dev libncurses6 libncurses-dev ncurses-base zlib1g-dev zlib1g libelf-dev

# my tools
sudo apt install -y ranger python3 python3-pip python3-venv screen curl
/usr/bin/python3 -m pip install --user --upgrade pip
/usr/bin/python3 -m pip install --user virtualenv numpy pandas matplotlib jupyterlab

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

# # zsh
# sudo apt install -y zsh
# sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# chsh -s $(which zsh)

# OPTIONAL: install starship prompt, and set it up with my config (you can change this lol)
curl -fsSL https://starship.rs/install.sh | sh -s -- -y
mkdir /home/cole/.config -p
curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/starship.toml -o /home/cole/.config/starship.toml

# # .zshrc
# echo 'ZSH="/home/cole/.oh-my-zsh"

# #Theme
# ZSH_THEME=""

# #Plugins
# plugins=(git zsh-autosuggestions)
# source $ZSH/oh-my-zsh.sh

# #Star Ship
# eval "$(starship init zsh)"
# ' > /home/cole/.zshrc
# echo "PATH=$PATH:/home/cole/.local/bin" >> /home/cole/.zshrc
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# # aliases, as a list
# "alias py='/usr/bin/python3'" >> /home/cole/.zshrc
# "alias pip='/usr/bin/python3 -m pip'" >> /home/cole/.zshrc
# "alias pip3='/usr/bin/python3 -m pip'" >> /home/cole/.zshrc
# "alias ll='ls -al'" >> /home/cole/.zshrc
# "alias 7z='/usr/local/bin/7zz'" >> /home/cole/.zshrc

# .bashrc
echo "alias py='/usr/bin/python3'" >> /home/cole/.bashrc
echo "alias pip='/usr/bin/python3 -m pip'" >> /home/cole/.bashrc
echo "alias pip3='/usr/bin/python3 -m pip'" >> /home/cole/.bashrc
echo "alias ll='ls -al'" >> /home/cole/.bashrc
echo "alias 7z='/usr/local/bin/7zz'" >> /home/cole/.bashrc
echo "eval \"\$(starship init bash)\"" >> /home/cole/.bashrc
echo "PATH=\$PATH:/home/cole/.local/bin" >> /home/cole/.bashrc

# setup verbose boot
# sudo apt install -y kernelstub
# sudo kernelstub --delete-options "quiet systemd.show_status=false splash"
# sudo kernelstub --add-options "systemd.show_status=true"

# welcome messages
sudo apt install -y inxi neofetch
sudo chmod -x /etc/update-motd.d/*
sudo curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/10-welcome -o /etc/update-motd.d/01-welcome
sudo chmod +x /etc/update-motd.d/01-welcome

# git config
git config --global user.email "cfuerth@satcomdirect.com"
git config --global user.name "Cole Fuerth"
git config --global core.editor "nano"
sudo bash -c "echo 'fs.inotify.max_user_watches=524288' >> /etc/sysctl.conf"
sudo sysctl -p

# need to add user to dialout group for serial access
sudo usermod -a -G dialout cole

# qemu dependencies
sudo apt install -y pkg-config autoconf automake libpng-dev libjpeg-dev libmodplug-dev libode-dev git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build git-email libaio-dev libbluetooth-dev libcapstone-dev libbrlapi-dev libbz2-dev libcap-ng-dev libcurl4-gnutls-dev libgtk-3-dev libibverbs-dev libjpeg8-dev libncurses5-dev libnuma-dev librbd-dev librdmacm-dev libsasl2-dev libsdl2-dev libseccomp-dev libsnappy-dev libssh-dev libvde-dev libvdeplug-dev libvte-2.91-dev libxen-dev liblzo2-dev valgrind xfslibs-dev libnfs-dev libiscsi-dev

# at the end we should run an update and autoremove in case anything was missed
sudo apt update
sudo apt autoremove -y

# need to ssh-keygen a new keypair for bitbucket
ssh-keygen -t rsa -b 4096 -C "cole-sd-vm" -f ~/.ssh/id_rsa
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
echo "copy this into github ------------"
more ~/.ssh/id_rsa.pub
echo "----------------------------------"
