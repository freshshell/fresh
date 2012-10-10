#!/bin/bash -e
#
# Install fresh with the following command:
#
#   bash -c "`curl -sL get.freshshell.com`"

mkdir -p ~/.fresh/source/jasoncodes

if [ -d ~/.fresh/source/jasoncodes/fresh ]; then
  cd ~/.fresh/source/jasoncodes/fresh
  git pull --rebase
  cd -
else
  git clone https://github.com/jasoncodes/fresh ~/.fresh/source/jasoncodes/fresh
fi

if ! [ -e ~/.freshrc ]; then
  echo 'fresh jasoncodes/fresh bin/fresh --bin' > ~/.freshrc
fi

~/.fresh/source/jasoncodes/fresh/bin/fresh

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
