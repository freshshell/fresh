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
  touch ~/.freshrc
fi

~/.fresh/source/jasoncodes/fresh/bin/fresh

cat <<-MESSAGE

  __               _           _
 / _|             | |         | |
| |_ _ __ ___  ___| |__    ___| |__
|  _| '__/ _ \/ __| '_ \  / __| '_ \\
| | | | |  __/\__ \ | | |_\__ \ | | |
|_| |_|  \___||___/_| |_(_)___/_| |_|
http://freshshell.com/

Add \`source ~/.fresh/build/shell.sh\` to your shell config.
MESSAGE
