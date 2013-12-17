#!/bin/bash
#
# Install fresh with the following command:
#
#   bash -c "`curl -sL get.freshshell.com`"

set -e

mkdir -p ~/.fresh/source/freshshell

if [ -d ~/.fresh/source/freshshell/fresh ]; then
  cd ~/.fresh/source/freshshell/fresh
  git pull --rebase
  cd "$OLDPWD"
else
  git clone https://github.com/freshshell/fresh ~/.fresh/source/freshshell/fresh
fi

FRESH_LOCAL="${FRESH_LOCAL:-$HOME/.dotfiles}"
if [ -n "$FRESH_LOCAL_SOURCE" ] && ! [ -d "$FRESH_LOCAL" ]; then
  if ! [[ "$FRESH_LOCAL_SOURCE" == */* || "$FRESH_LOCAL_SOURCE" == *:* ]]; then
    echo 'FRESH_LOCAL_SOURCE must be either in user/repo format or a full Git URL.' >&2
    exit 1
  fi

  if echo "$FRESH_LOCAL_SOURCE" | grep -q :; then
    git clone "$FRESH_LOCAL_SOURCE" "$FRESH_LOCAL"
  else
    git clone "https://github.com/$FRESH_LOCAL_SOURCE.git" "$FRESH_LOCAL"
    git --git-dir="$FRESH_LOCAL/.git" remote set-url --push origin "git@github.com:$FRESH_LOCAL_SOURCE.git"
  fi
fi

if ! [ -e ~/.freshrc ]; then
  if [ -r "$FRESH_LOCAL/freshrc" ]; then
    ln -s "$FRESH_LOCAL/freshrc" ~/.freshrc
  else
    cat << 'EOF' > ~/.freshrc
# freshshell.com
#
# Examples:
#
#   fresh twe4ked/dotfiles shell/functions/\*
#   fresh jasoncodes/dotfiles shell/aliases/rails.sh
#   fresh jasoncodes/dotfiles config/tmux.conf --file
#
# See http://freshshell.com/readme for documentation.

fresh freshshell/fresh bin/fresh --bin
EOF
  fi
fi

~/.fresh/source/freshshell/fresh/bin/fresh

cat <<-MESSAGE

  __               _
 / _|             | |
| |_ _ __ ___  ___| |__
|  _| '__/ _ \/ __| '_ \\
| | | | |  __/\__ \ | | |
|_| |_|  \___||___/_| |_|
http://freshshell.com/

MESSAGE
if ! [ -L ~/.freshrc ]; then
  cat <<-MESSAGE
You're all ready to get fresh!

Add \`$(echo $'\033[1;32msource ~/.fresh/build/shell.sh\033[0m')\` to your shell config.

Open a new shell, run \`fresh edit\` to start editing your .freshrc file
then run \`fresh\` to update your shell.

MESSAGE
fi
