#!/bin/bash

it_builds_local_shell_files() {
  echo fresh aliases/git >> $FRESH_RCFILE
  echo fresh aliases/ruby >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/aliases
  echo "alias gs='git status'" >> $FRESH_LOCAL/aliases/git
  echo "alias gl='git log'" >> $FRESH_LOCAL/aliases/git
  echo "alias rake='bundle exec rake'" >> $FRESH_LOCAL/aliases/ruby

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases/git

alias gs='git status'
alias gl='git log'

# fresh: aliases/ruby

alias rake='bundle exec rake'
EOF

  assertFalse 'not executable' '[ -x $FRESH_PATH/build/shell.sh ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/shell.sh ]'
}

it_builds_local_shell_files_with_spaces() {
  echo "fresh 'aliases/foo bar'" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/aliases
  echo SPACE > $FRESH_LOCAL/aliases/'foo bar'
  echo foo > $FRESH_LOCAL/aliases/foo
  echo bar > $FRESH_LOCAL/aliases/bar

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases/foo bar

SPACE
EOF
}

it_builds_local_shell_files_with_globbing() {
  echo "fresh 'aliases/file*'" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/aliases
  echo file1 > $FRESH_LOCAL/aliases/file1
  echo file2 > $FRESH_LOCAL/aliases/file2
  echo other > $FRESH_LOCAL/aliases/other

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases/file1

file1

# fresh: aliases/file2

file2
EOF
}

it_creates_empty_output_with_no_rcfile() {
  assertFalse 'file does not exist before' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  runFresh
  assertTrue 'file exists after' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"
EOF
}

it_errors_with_missing_local_file() {
  echo fresh foo >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/bar
  runFresh fails
}

it_preserves_existing_compiled_file_when_failing() {
  mkdir -p $FRESH_PATH/build
  echo 'existing file' > $FRESH_PATH/build/shell.sh
  cp $FRESH_PATH/build/shell.sh $SANDBOX_PATH/ref_shell.sh

  echo invalid >> $FRESH_RCFILE
  runFresh fails

  assertTrue 'file exists' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  diff -U2 $SANDBOX_PATH/ref_shell.sh $FRESH_PATH/build/shell.sh
  assertTrue 'original content exists' $?
}

it_clones_github_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  stubGit

  runFresh

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $(pwd)
git clone https://github.com/repo/name $SANDBOX_PATH/fresh/source/repo/name
EOF
  assertFileMatches $FRESH_PATH/source/repo/name/file <<EOF
test data
EOF
}

it_clones_other_repos() {
  echo fresh git://example.com/one/two.git file >> $FRESH_RCFILE
  echo fresh http://example.com/foo file >> $FRESH_RCFILE
  echo fresh https://example.com/bar file >> $FRESH_RCFILE
  echo fresh git@test.example.com:baz.git file >> $FRESH_RCFILE
  stubGit

  runFresh

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $(pwd)
git clone git://example.com/one/two.git $SANDBOX_PATH/fresh/source/example.com/one-two
cd $(pwd)
git clone http://example.com/foo $SANDBOX_PATH/fresh/source/example.com/foo
cd $(pwd)
git clone https://example.com/bar $SANDBOX_PATH/fresh/source/example.com/bar
cd $(pwd)
git clone git@test.example.com:baz.git $SANDBOX_PATH/fresh/source/test.example.com/baz
EOF
}

it_does_not_clone_existing_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  stubGit
  mkdir -p $FRESH_PATH/source/repo/name
  touch $FRESH_PATH/source/repo/name/file

  runFresh

  assertFalse 'did not run git' '[ -f $SANDBOX_PATH/git.log ]'
}

it_builds_shell_files_from_cloned_github_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name
  echo remote content > $FRESH_PATH/source/repo/name/file

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: repo/name file

remote content
EOF
}

it_builds_shell_files_from_cloned_other_repos() {
  echo fresh git://example.com/foobar.git file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/example.com/foobar
  echo remote content > $FRESH_PATH/source/example.com/foobar/file

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: git://example.com/foobar.git file

remote content
EOF
}

it_builds_with_ref_locks() {
  echo fresh repo/name 'aliases/*' --ref=abc1237 >> $FRESH_RCFILE
  echo fresh repo/name ackrc --file --ref=1234567 >> $FRESH_RCFILE
  echo fresh repo/name sedmv --bin --ref=abcdefg >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name/aliases
  # test with only one of aliases/* existing at HEAD
  touch $FRESH_PATH/source/repo/name/aliases/git.sh
  stubGit

  runFresh

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/repo/name
git ls-tree -r --name-only abc1237
cd $FRESH_PATH/source/repo/name
git show abc1237:aliases/git.sh
cd $FRESH_PATH/source/repo/name
git show abc1237:aliases/ruby.sh
cd $FRESH_PATH/source/repo/name
git ls-tree -r --name-only 1234567
cd $FRESH_PATH/source/repo/name
git show 1234567:ackrc
cd $FRESH_PATH/source/repo/name
git ls-tree -r --name-only abcdefg
cd $FRESH_PATH/source/repo/name
git show abcdefg:sedmv
EOF

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: repo/name aliases/git.sh @ abc1237

test data for abc1237:aliases/git.sh

# fresh: repo/name aliases/ruby.sh @ abc1237

test data for abc1237:aliases/ruby.sh
EOF
  assertFileMatches $FRESH_PATH/build/ackrc <<EOF
test data for 1234567:ackrc
EOF
  assertFileMatches $FRESH_PATH/build/bin/sedmv <<EOF
test data for abcdefg:sedmv
EOF
}

it_errors_if_source_file_missing_at_ref() {
  echo fresh repo/name bad-file --ref=abc1237 >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name
  stubGit

  runFresh fails

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/repo/name
git ls-tree -r --name-only abc1237
EOF
}

it_ignores_subdirectories_when_globbing_from_working_tree() {
  echo "fresh 'recursive-test/*'" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/recursive-test/abc
  touch $FRESH_LOCAL/recursive-test/{abc/def,foo,bar}

  runFresh

  assertFileMatches <(grep '^# fresh' $FRESH_PATH/build/shell.sh) <<EOF
# fresh: recursive-test/bar
# fresh: recursive-test/foo
EOF
}

it_ignores_subdirectories_when_globbing_with_ref() {
  echo "fresh repo/name 'recursive-test/*' --ref=abc1237" >> $FRESH_RCFILE
  stubGit

  runFresh

  assertFileMatches <(grep '^# fresh' $FRESH_PATH/build/shell.sh) <<EOF
# fresh: repo/name recursive-test/bar @ abc1237
# fresh: repo/name recursive-test/foo @ abc1237
EOF
}

it_builds_generic_files() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc --marker' >> $FRESH_RCFILE
  echo 'fresh config/git/colors --file=~/.gitconfig' >> $FRESH_RCFILE
  echo 'fresh config/git/rebase --file=~/.gitconfig' >> $FRESH_RCFILE
  echo 'fresh config/\*.vim --file=~/.vimrc --marker=\"' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/{lib,config/git}
  echo unbind C-b >> $FRESH_LOCAL/lib/tmux.conf
  echo set -g prefix C-a >> $FRESH_LOCAL/lib/tmux.conf
  echo Pry.config.color = true >> $FRESH_LOCAL/lib/pryrc.rb
  echo Pry.config.history.should_save = true >> $FRESH_LOCAL/lib/pryrc.rb
  echo '[color]' >> $FRESH_LOCAL/config/git/colors
  echo 'ui = auto' >> $FRESH_LOCAL/config/git/colors
  echo '[rebase]' >> $FRESH_LOCAL/config/git/rebase
  echo 'autosquash = true' >> $FRESH_LOCAL/config/git/rebase
  echo 'map Y y$' >> $FRESH_LOCAL/config/mappings.vim
  echo 'set hidden' >> $FRESH_LOCAL/config/global.vim

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"
EOF
  assertFileMatches $FRESH_PATH/build/tmux.conf <<EOF
unbind C-b
set -g prefix C-a
EOF
  assertFileMatches $FRESH_PATH/build/pryrc <<EOF
# fresh: lib/pryrc.rb

Pry.config.color = true
Pry.config.history.should_save = true
EOF
  assertFileMatches $FRESH_PATH/build/gitconfig <<EOF
[color]
ui = auto
[rebase]
autosquash = true
EOF

  assertFileMatches $FRESH_PATH/build/vimrc <<EOF
" fresh: config/global.vim

set hidden

" fresh: config/mappings.vim

map Y y$
EOF

  assertFalse 'not executable' '[ -x $FRESH_PATH/build/shell.sh ]'
  assertFalse 'not executable' '[ -x $FRESH_PATH/build/tmux.conf ]'
  assertFalse 'not executable' '[ -x $FRESH_PATH/build/pryrc ]'
  assertFalse 'not executable' '[ -x $FRESH_PATH/build/gitconfig ]'
  assertFalse 'not executable' '[ -x $FRESH_PATH/build/vimrc ]'

  assertFalse 'not world readable' '[ "$(find "$FRESH_PATH/build/shell.sh" -perm -004)" ]'
  assertFalse 'not world readable' '[ "$(find "$FRESH_PATH/build/tmux.conf" -perm -004)" ]'
  assertFalse 'not world readable' '[ "$(find "$FRESH_PATH/build/pryrc" -perm -004)" ]'
  assertFalse 'not world readable' '[ "$(find "$FRESH_PATH/build/gitconfig" -perm -004)" ]'
  assertFalse 'not world readable' '[ "$(find "$FRESH_PATH/build/vimrc" -perm -004)" ]'

  assertFalse 'not writable' '[ -w $FRESH_PATH/build/shell.sh ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/tmux.conf ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/pryrc ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/gitconfig ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/vimrc ]'
}

it_builds_generic_files_with_globbing() {
  echo "fresh 'file*' --file" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL
  echo file1 > $FRESH_LOCAL/file1
  echo file2 > $FRESH_LOCAL/file2
  echo other > $FRESH_LOCAL/other

  runFresh

  assertTrue 'file1 exists' '[ -f $FRESH_PATH/build/file1 ]'
  assertTrue 'file2 exists' '[ -f $FRESH_PATH/build/file2 ]'
  assertFalse 'other files do not exist' '[ -f $FRESH_PATH/build/other ]'
}

it_links_generic_files_to_destination() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc' >> $FRESH_RCFILE
  echo 'fresh .gitconfig --file' >> $FRESH_RCFILE
  echo 'fresh bclear.vim --file=~/.vim/colors/bclear.vim' >> $FRESH_RCFILE
  echo 'fresh "with spaces" --file="~/a path/with spaces"' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/lib
  touch $FRESH_LOCAL/{lib/tmux.conf,lib/pryrc.rb,.gitconfig,bclear.vim,with\ spaces}

  runFresh

  assertEquals "$FRESH_PATH/build/tmux.conf" "$(readlink ~/.tmux.conf)"
  assertEquals "$FRESH_PATH/build/pryrc" "$(readlink ~/.pryrc)"
  assertEquals "$FRESH_PATH/build/gitconfig" "$(readlink ~/.gitconfig)"
  assertEquals "$FRESH_PATH/build/vim-colors-bclear.vim" "$(readlink ~/.vim/colors/bclear.vim)"
  assertEquals "$FRESH_PATH/build/a-path-with-spaces" "$(readlink ~/a\ path/with\ spaces)"
}

it_builds_and_links_generic_files_with_same_basename() {
  echo 'fresh foo --file=~/.foo/file' >> $FRESH_RCFILE
  echo 'fresh bar --file=~/.bar/file' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  echo foo >> $FRESH_LOCAL/foo
  echo bar >> $FRESH_LOCAL/bar

  runFresh

  assertFileMatches $FRESH_PATH/build/foo-file <<EOF
foo
EOF
  assertFileMatches $FRESH_PATH/build/bar-file <<EOF
bar
EOF

  assertEquals "$FRESH_PATH/build/foo-file" "$(readlink ~/.foo/file)"
  assertEquals "$FRESH_PATH/build/bar-file" "$(readlink ~/.bar/file)"
}

it_does_not_link_generic_files_with_relative_paths() {
  echo 'fresh foo-bar.zsh --file=vendor/foo/bar.zsh' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foo-bar.zsh

  runFresh

  assertTrue 'file exists in build' '[ -f $FRESH_PATH/build/vendor/foo/bar.zsh ]'
  assertEquals "" "$(readlink vendor/foo/bar.zsh)"
}

it_does_not_allow_relative_paths_above_build_dir() {
  echo 'fresh foo-bar.zsh --file=../foo/bar.zsh' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foo-bar.zsh

  runFresh fails
}

it_builds_directories_of_generic_files() {
  echo 'fresh foo --file=vendor/misc/foo/' >> $FRESH_RCFILE
  echo 'fresh foo/bar --file=vendor/other/' >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/{foo/bar,foobar}
  touch $FRESH_LOCAL/foo/bar/file{1,2}
  touch $FRESH_LOCAL/foo/file3
  touch $FRESH_LOCAL/foobar/file{4,5}

  runFresh

  assertFileMatches <(cd $FRESH_PATH/build && find * -type f | sort) <<EOF
shell.sh
vendor/misc/foo/bar/file1
vendor/misc/foo/bar/file2
vendor/misc/foo/file3
vendor/other/file1
vendor/other/file2
EOF
}

it_builds_directories_of_generic_files_with_ref() {
  echo 'fresh repo/name recursive-test --ref=abc1237 --file=vendor/test/' >> $FRESH_RCFILE

  mkdir -p $FRESH_PATH/source/repo/name
  stubGit

  runFresh

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/repo/name
git ls-tree -r --name-only abc1237
cd $FRESH_PATH/source/repo/name
git show abc1237:recursive-test/abc/def
cd $FRESH_PATH/source/repo/name
git show abc1237:recursive-test/bar
cd $FRESH_PATH/source/repo/name
git show abc1237:recursive-test/foo
EOF

  assertFileMatches <(cd $FRESH_PATH/build && find * -type f | sort) <<EOF
shell.sh
vendor/test/abc/def
vendor/test/bar
vendor/test/foo
EOF
}

it_links_directories_of_generic_files() {
  echo 'fresh foo --file=~/.foo/' >> $FRESH_RCFILE
  echo 'fresh foo/bar --file=~/.other/' >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/{foo/bar,foobar}
  touch $FRESH_LOCAL/foo/bar/file{1,2}
  touch $FRESH_LOCAL/foo/file3
  touch $FRESH_LOCAL/foobar/file{4,5}

  runFresh

  assertFileMatches <(cd $FRESH_PATH/build && find * -type f | sort) <<EOF
foo/bar/file1
foo/bar/file2
foo/file3
other/file1
other/file2
shell.sh
EOF

  assertEquals "$FRESH_PATH/build/foo" "$(readlink ~/.foo)"
  assertEquals "$FRESH_PATH/build/other" "$(readlink ~/.other)"
  assertTrue 'can traverse symlink' '[ -f ~/.other/file1 ]'
}

it_builds_bin_files() {
  echo 'fresh scripts/sedmv --bin' >> $FRESH_RCFILE
  echo 'fresh pidof.sh --bin=~/bin/pidof' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/scripts
  echo foo >> $FRESH_LOCAL/scripts/sedmv
  echo bar >> $FRESH_LOCAL/pidof.sh

  runFresh

  assertFileMatches $FRESH_PATH/build/bin/sedmv <<EOF
foo
EOF
  assertFileMatches $FRESH_PATH/build/bin/pidof <<EOF
bar
EOF

  assertTrue 'is executable' '[ -x $FRESH_PATH/build/bin/sedmv ]'
  assertTrue 'is executable' '[ -x $FRESH_PATH/build/bin/pidof ]'

  assertFalse 'not writable' '[ -w $FRESH_PATH/build/bin/sedmv ]'
  assertFalse 'not writable' '[ -w $FRESH_PATH/build/bin/pidof ]'
}

it_builds_bin_files_with_globbing() {
  echo "fresh 'file*' --bin" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL
  echo file1 > $FRESH_LOCAL/file1
  echo file2 > $FRESH_LOCAL/file2
  echo other > $FRESH_LOCAL/other

  runFresh

  assertTrue 'file1 exists' '[ -f $FRESH_PATH/build/bin/file1 ]'
  assertTrue 'file2 exists' '[ -f $FRESH_PATH/build/bin/file2 ]'
  assertFalse 'other files do not exist' '[ -f $FRESH_PATH/build/bin/other ]'
}

it_links_bin_files_to_destination() {
  echo 'fresh scripts/sedmv --bin' >> $FRESH_RCFILE
  echo 'fresh pidof.sh --bin=~/bin/pidof' >> $FRESH_RCFILE
  echo 'fresh gemdiff --bin=~/bin/scripts/gemdiff' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/scripts
  touch $FRESH_LOCAL/{scripts/sedmv,pidof.sh,gemdiff}

  runFresh

  assertEquals "$FRESH_PATH/build/bin/sedmv" "$(readlink ~/bin/sedmv)"
  assertEquals "$FRESH_PATH/build/bin/pidof" "$(readlink ~/bin/pidof)"
  assertEquals "$FRESH_PATH/build/bin/gemdiff" "$(readlink ~/bin/scripts/gemdiff)"
}

it_runs_filters_on_files() {
  mkdir -p $FRESH_LOCAL
  echo "foo other_username bar" > $FRESH_LOCAL/aliases
  echo "fresh aliases --filter='sed s/other_username/my_username/ | tr _ -'" > $FRESH_RCFILE

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases # sed s/other_username/my_username/ | tr _ -

foo my-username bar
EOF
}

it_runs_filters_on_files_locked_to_a_ref() {
  mkdir -p $FRESH_LOCAL
  echo "fresh aliases/git.sh --ref=abc1237 --filter='sed s/test/TEST/'" > $FRESH_RCFILE

  stubGit

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases/git.sh @ abc1237 # sed s/test/TEST/

TEST data for abc1237:aliases/git.sh
EOF
}

it_errors_when_linking_bin_files_with_relative_paths() {
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foobar

  echo 'fresh foobar --bin=foobar' > $FRESH_RCFILE
  runFresh fails

  echo 'fresh foobar --bin=../foobar' > $FRESH_RCFILE
  runFresh fails
}

it_errors_if_existing_symlink_for_file_does_not_point_to_a_fresh_path() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  ln -s /dev/null ~/.pryrc

  bin/fresh > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX $HOME/.pryrc already exists (pointing to /dev/null)
$FRESH_RCFILE:1: fresh pryrc --file

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF

  assertEquals /dev/null "$(readlink ~/.pryrc)"
}

it_errors_if_existing_symlink_for_bin_does_not_point_to_a_fresh_path() {
  echo fresh bin/sedmv --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin ~/bin
  touch $FRESH_LOCAL/bin/sedmv
  ln -s /dev/null ~/bin/sedmv

  bin/fresh > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX $HOME/bin/sedmv already exists (pointing to /dev/null)
$FRESH_RCFILE:1: fresh bin/sedmv --bin

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF

  assertEquals /dev/null "$(readlink ~/bin/sedmv)"
}

it_does_not_error_for_symlinks_created_by_fresh() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  echo fresh bin/sedmv --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin
  touch $FRESH_LOCAL/pryrc
  touch $FRESH_LOCAL/bin/sedmv

  runFresh # build symlinks
  runFresh # run fresh again to check symlinks
}

it_replaces_old_symlinks_pointing_inside_the_fresh_build_directory() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/build $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  ln -s $FRESH_PATH/build/pryrc-old-name ~/.pryrc

  runFresh
  assertEquals $FRESH_PATH/build/pryrc "$(readlink ~/.pryrc)"
}

it_errors_if_link_destination_is_a_file() {
  mkdir -p $FRESH_LOCAL ~/bin
  touch $FRESH_LOCAL/{gitconfig,sedmv}
  echo foo > ~/.gitconfig
  echo bar > ~/bin/sedmv

  echo fresh gitconfig --file > $FRESH_RCFILE
  runFresh fails
  assertFileMatches ~/.gitconfig <<EOF
foo
EOF

  echo fresh sedmv --bin > $FRESH_RCFILE
  runFresh fails
  assertFileMatches ~/bin/sedmv <<EOF
bar
EOF
}

it_shows_source_of_errors() {
  mkdir -p $FRESH_LOCAL
  echo 'fresh bad-file' > $FRESH_RCFILE

  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/fresh_out.log ]'

  assertFileMatches $SANDBOX_PATH/fresh_err.log <<EOF
$ERROR_PREFIX Could not find "bad-file" source file.
$FRESH_RCFILE:1: fresh bad-file

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  mkdir -p $FRESH_LOCAL
  echo 'fresh repo/name some-file --blah' > $FRESH_RCFILE

  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/fresh_out.log ]'

  assertFileMatches $SANDBOX_PATH/fresh_err.log <<EOF
$ERROR_PREFIX Unknown option: --blah
$FRESH_RCFILE:1: fresh repo/name some-file --blah

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
Have a look at the repo: <$(_format_url https://github.com/repo/name)>
EOF

  echo 'source ~/.freshrc.local' > $FRESH_RCFILE
cat > $SANDBOX_PATH/home/.freshrc.local <<EOF
# local customisations

fresh pry.rb --file=~/.pryrc # ruby
fresh some-other-file
EOF

  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/fresh_out.log ]'

  assertFileMatches $SANDBOX_PATH/fresh_err.log <<EOF
$ERROR_PREFIX Could not find "pry.rb" source file.
~/.freshrc.local:3: fresh pry.rb --file=~/.pryrc # ruby

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF
}

it_updates_fresh_files() {
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git
  stubGit

  assertTrue 'successfully updates' "bin/fresh update"
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/other_repo/other_name
git pull --rebase
cd $FRESH_PATH/source/repo/name
git pull --rebase
EOF
}

it_updates_fresh_files_for_a_specified_github_user() {
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles/.git
  mkdir -p $FRESH_PATH/source/twe4ked/scripts/.git
  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  stubGit

  assertTrue 'successfully updates' "bin/fresh update twe4ked"
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/twe4ked/dotfiles
git pull --rebase
cd $FRESH_PATH/source/twe4ked/scripts
git pull --rebase
EOF
}

it_updates_fresh_files_for_a_specified_github_repo() {
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles/.git
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles-old/.git
  mkdir -p $FRESH_PATH/source/twe4ked/scripts/.git
  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  stubGit

  assertTrue 'successfully updates' "bin/fresh update twe4ked/dotfiles"
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/twe4ked/dotfiles
git pull --rebase
EOF
}

it_errors_if_no_matching_sources_to_update() {
  mkdir -p $FRESH_PATH/source

  bin/fresh update foobar > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"

  assertFileMatches "$SANDBOX_PATH/err.log" <<EOF
$ERROR_PREFIX No matching sources found.
EOF
}

it_errors_if_more_than_one_argument_is_passed_to_update() {
  mkdir -p $FRESH_PATH/source

  bin/fresh update twe4ked dotfiles > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"

  assertFileMatches "$SANDBOX_PATH/err.log" <<EOF
$ERROR_PREFIX Invalid arguments.

usage: fresh update <filter>

    The filter can be either a GitHub username or username/repo.
EOF
}

it_shows_progress_when_updating() {
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git
  stubGit

  bin/fresh update > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertTrue 'successfully updates' $?
  assertTrue 'outputs "repo/name"' 'grep -qxF "* Updating repo/name" $SANDBOX_PATH/fresh_out.log'
  assertTrue 'shows git output with prefix' 'grep -qxF "| Current branch master is up to date." $SANDBOX_PATH/fresh_out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_a_github_compare_url_when_updating() {
  stubGit

  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  cat > $FRESH_PATH/source/jasoncodes/dotfiles/.git/output <<EOF
From https://github.com/jasoncodes/dotfiles
   47ad84c..57b8b2b  master     -> origin/master
First, rewinding head to replay your work on top of it...
Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
EOF

  bin/fresh update > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertTrue 'successfully updates' $?
  assertTrue 'shows GitHub compare URL' 'grep -qF "https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b" $SANDBOX_PATH/fresh_out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_no_url_when_updating_other_repos() {
  stubGit

  mkdir -p $FRESH_PATH/source/gitorious.org/willgit-mainline/.git
  cat > $FRESH_PATH/source/gitorious.org/willgit-mainline/.git/output <<EOF
From git://gitorious.org/willgit/mainline
   67444ba..a2322a5  master     -> origin/master
EOF

  bin/fresh update > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertTrue 'successfully updates' $?
  assertFalse 'does not output a compare URL' 'egrep -q "https?://" $SANDBOX_PATH/fresh_out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_logs_update_output() {
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git

  stubGit
  assertTrue 'successfully updates' "bin/fresh update"
  assertTrue 'creates a log file' '[[ "$(find "$FRESH_PATH/logs" -type f | wc -l)" -eq 1 ]]'
  assertTrue 'log file name' 'find "$FRESH_PATH/logs" -type f | egrep -q "/logs/update-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\\.log$"'

  assertFileMatches $FRESH_PATH/logs/* <<EOF
* Updating other_repo/other_name
| Current branch master is up to date.
* Updating repo/name
| Current branch master is up to date.
EOF
}

it_does_not_run_build_if_update_fails() {
  echo fresh aliases >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  echo "alias gs='git status'" >> $FRESH_LOCAL/aliases

  mkdir -p $FRESH_PATH/source/repo/name1/.git
  mkdir -p $FRESH_PATH/source/repo/name2/.git
  touch $FRESH_PATH/source/repo/name1/.git/failure
  stubGit

  assertFalse 'fails to update' "bin/fresh update"
  assertTrue 'output does not exist' '[ ! -f "$FRESH_PATH/build/shell.sh" ]'
}

it_builds_after_update_with_latest_binary() {
  echo fresh bin/fresh --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin $FRESH_PATH/source

  mkdir -p $FRESH_PATH/source/freshshell/fresh/.git
  stubGit

  echo "echo new >> \"$SANDBOX_PATH/fresh.log\"" >> $FRESH_LOCAL/bin/fresh

  assertTrue 'successfully updates' "bin/fresh update"

  assertFileMatches $SANDBOX_PATH/fresh.log <<EOF
new
EOF
}

it_does_not_error_if_freshrc_has_bin_fresh() {
  echo fresh bin/fresh --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin
  touch $FRESH_LOCAL/bin/fresh

  unset FRESH_NO_BIN_CHECK
  runFresh
}

it_errors_if_freshrc_is_missing_bin_fresh() {
  touch $FRESH_RCFILE

  unset FRESH_NO_BIN_CHECK
  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not build' '[ -d $FRESH_PATH/build ]'
  assertTrue 'mentions solution' 'grep -q "fresh freshshell/fresh bin/fresh --bin" $SANDBOX_PATH/fresh_err.log'
}

it_allows_bin_fresh_error_to_be_disabled() {
  touch $FRESH_RCFILE

  export FRESH_NO_BIN_CHECK=true
  runFresh
}

assert_parse_fresh_dsl_args() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    _parse_fresh_dsl_args "$@" > $SANDBOX_PATH/test_parse_fresh_dsl_args.out
    echo REPO_NAME="$REPO_NAME"
    echo FILE_NAME="$FILE_NAME"
    echo MODE="$MODE"
    echo MODE_ARG="$MODE_ARG"
    echo REF="$REF"
    echo MARKER="$MARKER"
    echo FILTER="$FILTER"
  ) > $SANDBOX_PATH/test_parse_fresh_dsl_args.log 2>&1
  echo EXIT_STATUS=$? >> $SANDBOX_PATH/test_parse_fresh_dsl_args.log
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.out < /dev/null
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.log
}

it_parses_fresh_dsl_args() {
  assert_parse_fresh_dsl_args aliases/git.sh <<EOF
REPO_NAME=
FILE_NAME=aliases/git.sh
MODE=
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args jasoncodes/dotfiles .gitconfig --file <<EOF
REPO_NAME=jasoncodes/dotfiles
FILE_NAME=.gitconfig
MODE=file
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args sedmv --bin <<EOF
REPO_NAME=
FILE_NAME=sedmv
MODE=bin
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args scripts/pidof.sh --bin=~/bin/pidof <<EOF
REPO_NAME=
FILE_NAME=scripts/pidof.sh
MODE=bin
MODE_ARG=~/bin/pidof
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf --ref=abc1237 <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=abc1237
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args tmux.conf --file --marker <<EOF
REPO_NAME=
FILE_NAME=tmux.conf
MODE=file
MODE_ARG=
REF=
MARKER=#
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args vimrc --file --marker='"' <<EOF
REPO_NAME=
FILE_NAME=vimrc
MODE=file
MODE_ARG=
REF=
MARKER="
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args vimrc --file --filter='sed s/nmap/nnoremap/' <<EOF
REPO_NAME=
FILE_NAME=vimrc
MODE=file
MODE_ARG=
REF=
MARKER=
FILTER=sed s/nmap/nnoremap/
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args foo --file --marker= <<EOF
$ERROR_PREFIX Marker not specified.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --bin --marker <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --marker=';' <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --file --ref <<EOF
$ERROR_PREFIX You must specify a Git reference.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --filter <<EOF
$ERROR_PREFIX You must specify a filter program.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --file --bin <<EOF
$ERROR_PREFIX Cannot have more than one mode.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args <<EOF
$ERROR_PREFIX Filename is required
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo bar baz <<EOF
$ERROR_PREFIX Expected 1 or 2 args.
EXIT_STATUS=1
EOF
}

it_searches_directory_for_keywords() {
  stubCurl "foo" "bar baz"
  bin/fresh search foo bar > $SANDBOX_PATH/out.log 2> $SANDBOX_PATH/err.log
  assertTrue 'successfully executes' $?
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
foo
bar baz
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/curl.log <<EOF
curl
-sS
http://api.freshshell.com/directory
--get
--data-urlencode
q=foo bar
EOF
}

it_shows_error_if_no_search_query_given() {
  stubCurl
  bin/fresh search > $SANDBOX_PATH/out.log 2> $SANDBOX_PATH/err.log
  assertFalse 'returns error' $?
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX No search query given.
EOF
  assertFalse 'curl was not invoked' '[ -e "$SANDBOX_PATH/curl.log" ]'
}

it_shows_error_if_search_has_no_results() {
  stubCurl
  bin/fresh search crap > $SANDBOX_PATH/out.log 2> $SANDBOX_PATH/err.log
  assertFalse 'returns error' $?
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX No results.
EOF
  assertFileMatches $SANDBOX_PATH/curl.log <<EOF
curl
-sS
http://api.freshshell.com/directory
--get
--data-urlencode
q=crap
EOF
}

it_shows_error_if_search_api_call_fails() {
  stubCurl --fail "Could not connect."
  bin/fresh search blah > $SANDBOX_PATH/out.log 2> $SANDBOX_PATH/err.log
  assertFalse 'returns error' $?
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
Could not connect.
EOF
  assertFileMatches $SANDBOX_PATH/curl.log <<EOF
curl
-sS
http://api.freshshell.com/directory
--get
--data-urlencode
q=blah
EOF
}

it_cleans_dead_symlinks_from_home_and_bin() {
  echo 'fresh alive --file' >> $FRESH_RCFILE
  echo 'fresh alive --bin' >> $FRESH_RCFILE
  echo 'fresh dead --file' >> $FRESH_RCFILE
  echo 'fresh dead --bin' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{alive,dead}
  runFresh
  rm -f $FRESH_PATH/build/{dead,bin/dead}
  ln -s no_such_file ~/.other
  ln -s no_such_file ~/bin/other

  bin/fresh clean > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
  assertTrue 'successfully cleans' $?

  assertTrue '~/.alive still exists' '[ -L ~/.alive ]'
  assertTrue '~/bin/alive still exists' '[ -L ~/bin/alive ]'
  assertFalse '~/.dead no longer exists' '[ -L ~/.dead ]'
  assertFalse '~/bin/dead no longer exists' '[ -L ~/bin/dead ]'
  assertTrue '~/.other still exists' '[ -L ~/.other ]'
  assertTrue '~/bin/other still exists' '[ -L ~/bin/other ]'

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Removing ~/.dead
Removing ~/bin/dead
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_cleans_repositories_no_longer_referenced_by_freshrc() {
  echo 'fresh foo/bar file' >> $FRESH_RCFILE
  echo 'fresh git://example.com/foobar.git file' >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/{foo/bar,foo/baz,abc/def,example.com/foobar}/.git

  bin/fresh clean > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
  assertTrue 'successfully cleans' $?

  assertTrue 'foo/bar still exists' '[ -d "$FRESH_PATH/source/foo/bar/.git" ]'
  assertFalse 'foo/baz was cleaned' '[ -d "$FRESH_PATH/source/foo/baz/.git" ]'
  assertFalse 'abc/def was cleaned' '[ -d "$FRESH_PATH/source/abc/def" ]'
  assertFalse 'abc (empty parent) was cleaned' '[ -d "$FRESH_PATH/source/abc" ]'

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Removing source abc/def
Removing source foo/baz
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_shows_sources_for_fresh_lines() {
  echo 'fresh foo/bar aliases/*' >> $FRESH_RCFILE
  echo 'fresh foo/bar sedmv --bin --ref=abc123' >> $FRESH_RCFILE
  echo 'fresh local-file' >> $FRESH_RCFILE

  mkdir -p $FRESH_PATH/source/foo/bar/aliases/
  touch $FRESH_PATH/source/foo/bar/aliases/{git.sh,ruby.sh}
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/local-file

  stubGit

  bin/fresh show > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
  assertTrue 'successfully cleans' $?

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH/fresh/source/foo/bar
git log --pretty=%H -n 1 -- aliases/git.sh
cd $SANDBOX_PATH/fresh/source/foo/bar
git log --pretty=%H -n 1 -- aliases/ruby.sh
cd $SANDBOX_PATH/fresh/source/foo/bar
git ls-tree -r --name-only abc123
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
fresh foo/bar aliases/\\*
<$(_format_url https://github.com/foo/bar/blob/1234567/aliases/git.sh)>
<$(_format_url https://github.com/foo/bar/blob/1234567/aliases/ruby.sh)>

fresh foo/bar sedmv --bin --ref=abc123
<$(_format_url https://github.com/foo/bar/blob/abc123/sedmv)>

fresh local-file
<$(_format_url $FRESH_LOCAL/local-file)>
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_shows_git_urls_for_non_github_repos() {
  echo fresh git://example.com/one/two.git file >> $FRESH_RCFILE

  stubGit

  bin/fresh show > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
  assertTrue 'successfully cleans' $?

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
fresh git://example.com/one/two.git file
<$(_format_url git://example.com/one/two.git)>
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_escapes_arguments() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    _escape foo 'bar baz' > $SANDBOX_PATH/escape.out
  )
  assertTrue 'successfully escapes' $?
  assertFileMatches $SANDBOX_PATH/escape.out <<EOF
foo bar\\ baz
EOF
}

it_confirms_query_positive() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    echo y | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_negative() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    echo n | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertFalse 'returns false' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_default() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    echo | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_invalid() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    echo -e "blah\ny" | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_adds_lines_to_freshrc_for_local_files() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new\ file}

  yes | bin/fresh 'new file' > $SANDBOX_PATH/add.out 2> $SANDBOX_PATH/add.err
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
fresh new\\ file
EOF
  assertFileMatches $SANDBOX_PATH/add.out <<EOF
Add \`fresh new\\ file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh new\\ file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/add.err <<EOF
EOF
}

it_adds_lines_to_freshrc_for_new_remotes() {
  stubGit

  yes | bin/fresh user/repo file > $SANDBOX_PATH/add.out 2> $SANDBOX_PATH/add.err
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/add.out <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/add.err <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH
git clone https://github.com/user/repo $FRESH_PATH/source/user/repo
EOF
}

it_adds_lines_to_freshrc_for_existing_remotes() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  stubGit

  yes | bin/fresh user/repo file > $SANDBOX_PATH/add.out 2> $SANDBOX_PATH/add.err
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/add.out <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
Update local cache of user/repo [Y/n]? * Updating user/repo
| Current branch master is up to date.
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/add.err <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/user/repo
git pull --rebase
EOF
}

it_does_not_add_lines_to_freshrc_if_declined() {
  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new}

  yes n | bin/fresh new > $SANDBOX_PATH/add.out 2> $SANDBOX_PATH/add.err
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
EOF
  assertFileMatches $SANDBOX_PATH/add.out <<EOF
Add \`fresh new\` to $FRESH_RCFILE [Y/n]? $(echo $'\033[1;33mNote\033[0m:') Use \`fresh edit\` to manually edit your $FRESH_RCFILE.
EOF
  assertFileMatches $SANDBOX_PATH/add.err <<EOF
EOF
}

it_adds_lines_to_freshrc_without_updating_existing_repo_if_declined() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  stubGit

  (echo y; echo n) | bin/fresh user/repo file > $SANDBOX_PATH/add.out 2> $SANDBOX_PATH/add.err
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/add.out <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
Update local cache of user/repo [Y/n]? $(echo $'\033[1;33mNote\033[0m:') You can run \`fresh update user/repo\`.
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/add.err <<EOF
EOF
  assertFalse 'did not run git' '[ -f $SANDBOX_PATH/git.log ]'
}

it_applies_fresh_options_to_multiple_lines() {
  echo 'fresh-options --file=~/.vimrc --marker=\"' >> $FRESH_RCFILE
  echo "fresh mappings.vim --filter='tr a x'" >> $FRESH_RCFILE
  echo "fresh autocmds.vim" >> $FRESH_RCFILE
  echo "fresh-options" >> $FRESH_RCFILE
  echo "fresh zshrc --file" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL
  echo "mappings" >> $FRESH_LOCAL/mappings.vim
  echo "autocmds" >> $FRESH_LOCAL/autocmds.vim
  echo "zsh config" >> $FRESH_LOCAL/zshrc

  runFresh

  assertFileMatches $FRESH_PATH/build/vimrc <<EOF
" fresh: mappings.vim # tr a x

mxppings

" fresh: autocmds.vim

autocmds
EOF

  assertFileMatches $FRESH_PATH/build/zshrc <<EOF
zsh config
EOF
}

source test/test_helper.sh
