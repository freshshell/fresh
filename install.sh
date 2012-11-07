#!/bin/bash -e
#
# Install fresh with the following command:
#
#   bash -c "`curl -sL get.freshshell.com`"

mkdir -p ~/.fresh/source/freshshell

if [ -d ~/.fresh/source/freshshell/fresh ]; then
  cd ~/.fresh/source/freshshell/fresh
  git pull --rebase
  cd -
else
  git clone https://github.com/freshshell/fresh ~/.fresh/source/freshshell/fresh
fi

if ! [ -e ~/.freshrc ]; then
  echo 'fresh freshshell/fresh bin/fresh --bin' > ~/.freshrc
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

You're all ready to get fresh!

Add \`$(echo $'\033[1;32msource ~/.fresh/build/shell.sh\033[0m')\` to your shell config.

MESSAGE
