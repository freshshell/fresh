# Fresh

Keep your dot files fresh.

[![Build Status](https://secure.travis-ci.org/jasoncodes/fresh.png)](http://travis-ci.org/jasoncodes/fresh)

## Installation

Install [fresh](http://freshshell.com/) with the following:

``` sh
bash -c "`curl -sL get.freshshell.com`"
```

This will:

* Create a `~/.fresh` directory.
* Clone the latest version of fresh into `~/.fresh/source/jasoncodes/fresh`.
* Create a `~/.freshrc` file.

You will need to manually add `source ~/.fresh/build/shell.sh` to your shell config.

## Usage

An example `freshrc` file:

``` sh
fresh jasoncodes/fresh bin/fresh --bin                # handles updating fresh
fresh twe4ked/dotfiles aliases/git.sh                 # builds the aliases/git file into ~/.fresh/build/shell.sh
fresh twe4ked/dotfiles lib/ackrc --file               # links the lib/ackrc file to ~/.ackrc
fresh jasoncodes/scripts gemdiff --bin=~/bin/gem-diff # links the gemdiff file to ~/bin/gem-diff
```

Running `fresh` will then build your shell configuration and create any relevant symbolic links.
