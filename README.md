# My Dot-Files

as a side note, for some of this, it may be better to just `curl` the script to a local file and copy paste sections at a time, as some of the menus require user input and may not be fully tested. I more or less just did a bunch of stuff manually and then threw it in a script after the fact.

## Installation

```bash
sudo apt update && sudo apt install -y curl
curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/ubuntu-bringup.sh | bash
```

**note: if you aren't *me* then do this instead:**\
(there are flags at the start of the script that turn features on and off)

```bash
sudo apt update && sudo apt install -y curl
curl -fsSL https://raw.githubusercontent.com/colefuerth/dot-files/master/ubuntu-bringup-generic.sh | bash
```

*also note that this one is untested*

## About

Setting up takes *forever* and is a huge waste of time, so I threw everything in this repo that I need to get a fresh distro going in just a few minutes. Everything I need for a dev environment is in here, and as I add more stuff I am updating these scripts.

*note: this does require some babysitting, I didn't automate all of the menus*
