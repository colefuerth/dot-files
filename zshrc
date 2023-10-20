ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME=""

# Plugins
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# Load Zsh alias files from ~/zsh_aliases/
for file in $HOME/.zsh_aliases/*; do
    [ -r "$file" ] && source "$file"
done
