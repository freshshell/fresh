# fresh

Keep your dot files fresh.

fresh is a tool to source shell configuration (aliases, functions, etc) from
others into your own configuration files. We also support files such as ackrc
and gitconfig. Think of it as Bundler for your dot files.

You can use `fresh search` to find fresh lines that have been
added to the [directory].

[![Build Status](https://secure.travis-ci.org/freshshell/fresh.png?branch=master)](http://travis-ci.org/freshshell/fresh)

## Contents

- [Installation](#installation)
- [Usage](#usage)
	- [Sources](#sources)
	- [Shell files](#shell-files)
	- [Config files](#config-files)
	- [Bin files](#bin-files)
	- [Locking to specific Git references](#locking-to-specific-git-references)
	- [Filters](#filters)
	- [Option Blocks](#option-blocks)
	- [Advanced Usage](#advanced-usage)
- [Command line options](#command-line-options)
- [Maintainers](#maintainers)
- [Licence](#licence)

## Installation

Install [fresh](http://freshshell.com/) with the following:

``` sh
bash -c "`curl -sL get.freshshell.com`"
```

This will:

* Create a `~/.fresh` directory.
* Clone the latest version of fresh into `~/.fresh/source/freshshell/fresh`.
* Create a `~/.freshrc` file.

You will need to manually add `source ~/.fresh/build/shell.sh` to your shell config.

### Manual steps

Don't want to run our shell script? The installation is simple:

``` sh
git clone https://github.com/freshshell/fresh ~/.fresh/source/freshshell/fresh
echo "fresh freshshell/fresh bin/fresh --bin" >> ~/.freshrc
~/.fresh/source/freshshell/fresh/bin/fresh # run fresh
# Add `source ~/.fresh/build/shell.sh` to your shell config.
```

## Usage

An example `~/.freshrc` file:

``` sh
# handles updating fresh
fresh freshshell/fresh bin/fresh --bin

# links your local ~/.dotfiles/gitconfig to ~/.gitconfig (you can change your local directory by setting $FRESH_LOCAL)
fresh gitconfig --file

# builds jasoncodes' aliases into ~/.fresh/build.sh
fresh jasoncodes/dotfiles shell/aliases/\*

# builds the shell/aliases/git.sh file into ~/.fresh/build/shell.sh
fresh twe4ked/dotfiles shell/aliases/git.sh

# links the config/ackrc file to ~/.ackrc
fresh twe4ked/dotfiles config/ackrc --file

# builds config/notmuch-config.erb with erb and links it to ~/.notmuch-config
fresh neersighted/dotfiles config/notmuch-config.erb --file=~/.notmuch-config --filter=erb

# links the gemdiff file to ~/bin/gem-diff
fresh jasoncodes/dotfiles bin/gemdiff --bin=~/bin/gem-diff

# builds the aliases/github.sh file locked to the specified git ref
fresh twe4ked/dotfiles aliases/github.sh --ref=bea8134
```

Running `fresh` will then build your shell configuration and create any relevant symbolic links.

### Sources

#### Local files

If no remote source is specified (`github_user/repo_name`), fresh will look for local files relative to `~/.dotfiles/`.

For example the following fresh line will look for `~/.dotfiles/shell/aliases/git.sh`.

``` sh
fresh shell/aliases/git.sh
```

#### GitHub repositories

To source from a GitHub repository you can specify the username and repo name separated with a slash:

``` sh
fresh username/repo example.sh
```

#### Non-GitHub sources

You can also source from non-GitHub repositories by specifying the full git clone URL:

``` sh
fresh git://example.com/path/to/repo.git example.sh
```

### Shell files

With no options, fresh will join specified shell files together.

``` sh
fresh twe4ked/dotfiles shell/aliases/git.sh
fresh jasoncodes/dotfiles shell/aliases/\*
```

Joins the `shell/aliases/git.sh` file from [twe4ked/dotfiles] with the `shell/aliases/*` files
from [jasoncodes/dotfiles] into `~/.fresh/build/shell.sh`.

### Config files

``` sh
fresh twe4ked/dotfiles config/ackrc --file
fresh example/dotfiles pry.rb --file=~/.pryrc
```

Links the `config/ackrc` file from [twe4ked/dotfiles] to `~/.ackrc`
and the `pry.rb` file from example/dotfiles to `~/.pryrc`.

#### A single config file built from multiple sources

``` sh
fresh jasoncodes/dotfiles config/tmux.conf --file
fresh twe4ked/dotfiles config/tmux.conf --file
```

Builds tmux configuration from both [jasoncodes/dotfiles] and [twe4ked/dotfiles]
together into a single `~/.tmux.conf` output.

#### Identifying source files in compiled output

Shell files automatically include comments before each section.
To add annotations to config files you can use the `--marker` option:

``` sh
fresh twe4ked/dotfiles 'vim/*' --file=~/.vimrc --marker='"'
fresh jasoncodes/dotfiles config/pryrc --file --marker
```

#### Sourcing whole directories of files

Whole directories or repositories can be built and symlinked by including a trailing slash on the `--file` path:

``` sh
fresh mutt --file=~/.mutt/
fresh tpope/vim-pathogen . --file=~/.vim/bundle/vim-pathogen/ # whole repository
```

#### Building files without symlinking

Some tools/libraries (e.g. zsh plugins) require specific directory structures.
These can be built within the build directory (`~/.fresh/build`) by specifying
a relative path on `--file`:

``` sh
fresh zsh-users/zsh-syntax-highlighting zsh-syntax-highlighting.zsh --file=vendor/zsh-syntax-highlighting.zsh
fresh zsh-users/zsh-syntax-highlighting highlighters --file=vendor/highlighters/
```

These files can then be sourced from your main shell config with:

``` sh
source ~/.fresh/build/vendor/zsh-syntax-highlighting.zsh
```

### Bin files

``` sh
fresh jasoncodes/dotfiles bin/sedmv --bin
fresh jasoncodes/dotfiles bin/gemdiff --bin=~/bin/gem-diff
```

Links the `sedmv` file from [jasoncodes/dotfiles] to `~/bin/sedmv`
and the `gemdiff` file from [jasoncodes/dotfiles] to `~/bin/gem-diff`.

### Locking to specific Git references

``` sh
fresh twe4ked/dotfiles aliases/github.sh --ref=bea8134
```

Locks the `aliases/github.sh` file to the specified commit.
You can use any Git reference: branches, commit hashes, tags, etc.

### Filters

[Filters][filters] allow you to run specified files through arbitrary commands at build time.

``` sh
fresh neersighted/dotfiles config/muttrc.erb.asc --file=~/.muttrc --filter="gpg | erb"
```

[filters]: https://github.com/freshshell/fresh/wiki/Filters

### Option Blocks

If you have a section of your `~/.freshrc` file where multiple lines need the same options
you can use `fresh-options` to reduce duplication.

``` sh
# ~/.freshrc
fresh-options --file=~/.vimrc --marker=\"
  fresh twe4ked/dotfiles vim/vundle_before.vim
  fresh vim/vundle.vim
  fresh twe4ked/dotfiles vim/vundle_after.vim
  fresh vim/mappings.vim
fresh-options
```

`fresh-options` overrides any previous `fresh-options` calls.
Passing no arguments resets back to the default.

### Advanced Usage

There are many other ways you can customize fresh.
Check out our [advanced usage wiki pages][advanced usage] for more information.

[advanced usage]: https://github.com/freshshell/fresh/wiki#advanced-usage

## Command line options

### Install

Running `fresh` or `fresh install` will build shell configuration and relevant
symlinks.

### Update

Running `fresh update` will update sources from GitHub repositories and run `fresh install`.

You can also optionally supply a GitHub username or username/repo:

``` sh
fresh update jasoncodes       # update all jasoncodes' repos
fresh update twe4ked/dotfiles # update twe4ked's dotfiles
```

#### Local dotfiles

`fresh update` without any arguments will also fetch any changes made to your local dotfiles stored in `~/.dotfiles`.
You can update just your local dofiles by specifying the `--local` option.

### Clean

When you remove a source from your `~/.freshrc` or remove a `--file`/`--bin`
line, you can use `fresh clean` to remove dead symlinks and source repos.

### Search

You can search our [fresh directory][directory] using `fresh search`.
Feel free to add your own fresh lines to the wiki page!

Try:

``` sh
fresh search twe4ked
fresh search jasoncodes
# or
fresh search ruby
```

### Edit

Running `fresh edit` will open your `~/.freshrc` in your default `$EDITOR`.

### Show

`fresh show` will output each line of your `~/.freshrc` along with
every source file those lines match. Handy for auditing.

### Subcommands

fresh will detect bin files that start with `fresh-` in your `$PATH`.

For example running `fresh open` is equivalent to running `fresh-open`.

### Adding Lines Directly From The Command line

You can append fresh lines to your freshrc directly from the command line.

Try running:

``` sh
fresh twe4ked/catacomb bin/catacomb --bin
# or
fresh https://github.com/twe4ked/catacomb/blob/master/bin/catacomb
```

You will then get a prompt comfirming that you wish to add the new line.
You can then modify it if needed by running `fresh edit`.

## Maintainers

fresh is maintained by [jasoncodes] and [twe4ked].

## Licence

MIT

![Analytics](https://ga-beacon.appspot.com/UA-35374397-2/fresh/readme?pixel)

[jasoncodes/dotfiles]: https://github.com/jasoncodes/dotfiles
[twe4ked/dotfiles]: https://github.com/twe4ked/dotfiles
[jasoncodes]: https://github.com/jasoncodes
[twe4ked]: https://github.com/twe4ked
[directory]: https://github.com/freshshell/fresh/wiki/Directory
