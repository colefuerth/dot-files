ZSH="/home/$USER/.oh-my-zsh"

# Theme
ZSH_THEME=""

# Plugins
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# pcp() {
#   if [ -z "$1" ] || [ -z "$2" ]; then
#     echo "Usage: pcp source dest"
#     return 1
#   fi

#   # Create the destination directory if it doesn't exist

#   if [ -d "$1" ]; then
#     # If the source is a directory, copy its contents to the destination
#     mkdir -p "$2"
#     (cd "$1" && tar cf - .) | pv -s "$(du -sb '.' | awk '{print $1}')" | (cd "$2" && tar xf -)
#   else
#     # If the source is a file, copy it directly to the destination
#     pv "$1" > "$2"
#   fi
# }
