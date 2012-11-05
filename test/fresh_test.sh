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
alias gs='git status'
alias gl='git log'
alias rake='bundle exec rake'
EOF
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
file1
file2
EOF
}

it_creates_empty_output_with_no_rcfile() {
  assertFalse 'file does not exist before' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  runFresh
  assertTrue 'file exists after' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
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
git clone http://github.com/repo/name $SANDBOX_PATH/fresh/source/repo/name
EOF
  assertFileMatches $FRESH_PATH/source/repo/name/file <<EOF
test data
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

it_builds_shell_files_from_cloned_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name
  echo remote content > $FRESH_PATH/source/repo/name/file

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
remote content
EOF
}

it_builds_generic_files() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc' >> $FRESH_RCFILE
  echo 'fresh .gitconfig --file' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/lib
  echo unbind C-b >> $FRESH_LOCAL/lib/tmux.conf
  echo set -g prefix C-a >> $FRESH_LOCAL/lib/tmux.conf
  echo Pry.config.color = true >> $FRESH_LOCAL/lib/pryrc.rb
  echo Pry.config.history.should_save = true >> $FRESH_LOCAL/lib/pryrc.rb
  echo '[color]' >> $FRESH_LOCAL/.gitconfig
  echo 'ui = auto' >> $FRESH_LOCAL/.gitconfig

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
EOF
  assertFileMatches $FRESH_PATH/build/tmux.conf <<EOF
unbind C-b
set -g prefix C-a
EOF
  assertFileMatches $FRESH_PATH/build/pryrc <<EOF
Pry.config.color = true
Pry.config.history.should_save = true
EOF
  assertFileMatches $FRESH_PATH/build/gitconfig <<EOF
[color]
ui = auto
EOF
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
  assertFalse 'other files do not exist' '[ -f $FRESH_BUILD/other ]'
}

it_links_generic_files_to_destination() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc' >> $FRESH_RCFILE
  echo 'fresh .gitconfig --file' >> $FRESH_RCFILE
  echo 'fresh bclear.vim --file=~/.vim/colors/bclear.vim' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/lib
  touch $FRESH_LOCAL/{lib/tmux.conf,lib/pryrc.rb,.gitconfig,bclear.vim}

  runFresh

  assertEquals "$(readlink ~/.tmux.conf)" "$FRESH_PATH/build/tmux.conf"
  assertEquals "$(readlink ~/.pryrc)" "$FRESH_PATH/build/pryrc"
  assertEquals "$(readlink ~/.gitconfig)" "$FRESH_PATH/build/gitconfig"
  assertEquals "$(readlink ~/.vim/colors/bclear.vim)" "$FRESH_PATH/build/bclear.vim"
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
  assertFalse 'other files do not exist' '[ -f $FRESH_BUILD/bin/other ]'
}

it_links_bin_files_to_destination() {
  echo 'fresh scripts/sedmv --bin' >> $FRESH_RCFILE
  echo 'fresh pidof.sh --bin=~/bin/pidof' >> $FRESH_RCFILE
  echo 'fresh gemdiff --bin=~/bin/scripts/gemdiff' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/scripts
  touch $FRESH_LOCAL/{scripts/sedmv,pidof.sh,gemdiff}

  runFresh

  assertEquals "$(readlink ~/bin/sedmv)" "$FRESH_PATH/build/bin/sedmv"
  assertEquals "$(readlink ~/bin/pidof)" "$FRESH_PATH/build/bin/pidof"
  assertEquals "$(readlink ~/bin/scripts/gemdiff)" "$FRESH_PATH/build/bin/gemdiff"
}

it_does_not_override_existing_links() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  echo fresh sedmv --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL ~/bin
  touch $FRESH_LOCAL/{pryrc,sedmv}
  ln -s /dev/null ~/.pryrc
  ln -s /dev/null ~/bin/sedmv

  runFresh

  assertEquals "$(readlink ~/.pryrc)" "/dev/null"
  assertEquals "$(readlink ~/bin/sedmv)" "/dev/null"
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

test_parse_fresh_dsl_args() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    parse_fresh_dsl_args "$@"
    echo REPO_NAME="$REPO_NAME"
    echo FILE_NAME="$FILE_NAME"
    echo MODE="$MODE"
    echo MODE_ARG="$MODE_ARG"
  ) > $SANDBOX_PATH/test_parse_fresh_dsl_args.log 2>&1
  echo EXIT_STATUS=$? >> $SANDBOX_PATH/test_parse_fresh_dsl_args.log
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.log
}

it_parses_fresh_dsl_args() {
  test_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args jasoncodes/dotfiles .gitconfig --file <<EOF
REPO_NAME=jasoncodes/dotfiles
FILE_NAME=.gitconfig
MODE=file
MODE_ARG=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args sedmv --bin <<EOF
REPO_NAME=
FILE_NAME=sedmv
MODE=bin
MODE_ARG=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args scripts/pidof.sh --bin=~/bin/pidof <<EOF
REPO_NAME=
FILE_NAME=scripts/pidof.sh
MODE=bin
MODE_ARG=~/bin/pidof
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args foo --file --bin <<EOF
Cannot have more than one mode.
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args <<EOF
Filename is required
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args foo bar baz <<EOF
Expected 1 or 2 args.
EXIT_STATUS=1
EOF
}

source test/test_helper.sh
