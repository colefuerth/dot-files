# My Dot-Files

This project is for quick bringup and easy synchronization of shell environments between my machines, and has been modified to also support configuration and mods.

## Installation on NixOS

### switch without cloning

```bash
sudo nixos-rebuild --flake github:colefuerth/dot-files#cole-laptop --log-format internal-json -v switch |& nom --json
```

### cloning and switching locally

```bash
nix run --extra-experimental-features nix-command --extra-experimental-features flakes nixpkgs#git -- clone https://github.com/colefuerth/dot-files.git
cd dot-files
sudo nixos-rebuild --flake .#cole-laptop --log-format internal-json -v switch |& nom --json
```

### build without deploying

```bash
nixos-rebuild --flake .#cole-laptop --log-format internal-json -v build |& nom --json
```

### test locally

```bash
sudo nixos-rebuild --flake .#cole-laptop test

## Installation on Ubuntu/Pop

First, we must clone the repo:

```bash
sudo apt update && sudo apt install -y git
git clone git@github.com:colefuerth/dot-files.git
```

I recommend configuring before installing; to configure:

```bash
cd dot-files
cp config.bash.example config.bash
nano config.bash # the #Configuration section details what each of these options do
```

To install, then run:

```bash
./install.sh
```

## Configuration

| Shell Config | Description |
| --- | --- |
| AUTO_UPDATE | Whenever a new terminal is opened, run `./update.sh` to pull any changes and include them in the session, so you are always on the latest release |
| INSTALL_ZSH | `sudo apt install zsh` |
| SETUP_ZSH | Install/load this repo to zsh |
| SETUP_BASH | Install/load this repo to bash |
| DEFAULT_SHELL | "zsh" or "bash"; runs `chsh` with whatever this is set to |
| INSTALL_STARSHIP | install [starship](https://starship.rs/) prompt |
| DEPLOYMENT_METHOD | "copy" just copies all of the files in this repo to the aliases directory, "softlink" creates symbolic links to the files in this repo |

| Tools Config | Description |
| --- | --- |
| SETUP_WELCOME_MSG | run `neofetch` on new terminal sessions |
| INSTALL_TOOLS | If this is false, nothing under the SUBTOOLS_CONFIG is installed. Recommended to leave this as `true` and just config the subtools |
| SETUP_SSH | Install openssh-server, open the ssh port, generate an rsa key if none are already generated at the default path |
| SETUP_DIALOUT | add the current user to the `dialout` group, needed to access serial consoles |
| SETUP_GIT | installs git and sets the global `user.name` and `user.email` (prompts user for each) |
| INSTALL_CCACHE | install the ccache 4.8.3 binaries from its github releases to /usr/local/bin |
| IS_VM | `sudo apt install open-vm-tools` (necessary for copy paste and x11 compatibility through most virtual machine managers) |

| SUBTOOL | Description |
| --- | --- |
| NCDU | NCurses Disk Usage is a TUI tool that recursively checks the `du` of each folder and is an excellent visual terminal tool for traversing folders |
| INSTALL_7Z | gets the latest 7zz binary from github releases (apt is on the 2016 release, this is the 2023 release), and if 7z is not already installed, aliases 7z to 7zz |
| HTOP | colorful TUI task manager if you care about that stuff (it's pleasing to look at when builds run) |
| RUST | Install rust using the rust.rs script (classic) |
| MCFLY | Context-sensitive, AI-powered search engine for your terminal history (I don't use this personally but it can be useful if you're into that) |
| ADVCPMV | Advanced copy/move mod for cp and mv; there is an alias in this repo `acp` and `amv` that enable a progress bar for copies and moves |
| CLIPBOARD | `cb` clipboard for terminal, files, extremely versatile and useful when you need it, has multiple clipboards so you can juggle things easily |
| PYTHON | install the python binaries from apt |
| PYTHON_EXT | "Python_Extended" installs some of the more "essential" pip packages like numpy and venv |
| MORE_TOOLS | space-separated list of additional apt packages to install |

## Adding Custom Aliases

By default, any shells configured with my tools auto source any files found under the `.zsh_aliases` or `.bash_aliases` directory, so you can just make your own file under that directory and add stuff there.
