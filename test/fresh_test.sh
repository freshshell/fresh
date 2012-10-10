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
export PATH="~/bin:\$PATH"
alias gs='git status'
alias gl='git log'
alias rake='bundle exec rake'
EOF
}

it_creates_empty_output_with_no_rcfile() {
  assertFalse 'file does not exist before' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  runFresh
  assertTrue 'file exists after' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="~/bin:\$PATH"
EOF
}

it_errors_with_missing_local_file() {
  echo fresh no_such_file >> $FRESH_RCFILE
  runFresh fails
}

it_preserves_existing_compiled_file_when_failing() {
  mkdir -p $FRESH_PATH/build
  echo 'existing file' > $FRESH_PATH/build/shell.sh
  cp $FRESH_PATH/build/shell.sh tmp/sandbox/ref_shell.sh

  echo invalid >> $FRESH_RCFILE
  runFresh fails

  assertTrue 'file exists' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  diff -U2 tmp/sandbox/ref_shell.sh $FRESH_PATH/build/shell.sh
  assertTrue 'original content exists' $?
}

it_clones_github_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p tmp/sandbox/bin
  cat > tmp/sandbox/bin/git <<EOF
#!/bin/bash -e
echo "\$@" >> tmp/sandbox/git.log
mkdir "\$3"
echo test data > "\$3/file"
EOF
  chmod +x tmp/sandbox/bin/git

  runFresh

  assertFileMatches tmp/sandbox/git.log <<EOF
clone http://github.com/repo/name tmp/sandbox/fresh/source/repo/name
EOF
  assertFileMatches $FRESH_PATH/source/repo/name/file <<EOF
test data
EOF
}

it_does_not_clone_existing_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p tmp/sandbox/bin
  cat > tmp/sandbox/bin/git <<EOF
#!/bin/bash -e
echo "\$@" >> tmp/sandbox/git.log
EOF
  chmod +x tmp/sandbox/bin/git
  mkdir -p $FRESH_PATH/source/repo/name
  touch $FRESH_PATH/source/repo/name/file

  runFresh

  assertFalse 'did not run git' '[ -f tmp/sandbox/git.log ]'
}

it_builds_shell_files_from_cloned_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name
  echo remote content > $FRESH_PATH/source/repo/name/file

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="~/bin:\$PATH"
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
export PATH="~/bin:\$PATH"
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

it_links_generic_files_to_destination() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc' >> $FRESH_RCFILE
  echo 'fresh .gitconfig --file' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/lib
  touch $FRESH_LOCAL/{lib/tmux.conf,lib/pryrc.rb,.gitconfig}

  runFresh

  assertEquals "$(readlink ~/.tmux.conf)" "$FRESH_PATH/build/tmux.conf"
  assertEquals "$(readlink ~/.pryrc)" "$FRESH_PATH/build/pryrc"
  assertEquals "$(readlink ~/.gitconfig)" "$FRESH_PATH/build/gitconfig"
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

it_links_bin_files_to_destination() {
  echo 'fresh scripts/sedmv --bin' >> $FRESH_RCFILE
  echo 'fresh pidof.sh --bin=~/bin/pidof' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/scripts
  touch $FRESH_LOCAL/{scripts/sedmv,pidof.sh}

  runFresh

  assertEquals "$(readlink ~/bin/sedmv)" "$FRESH_PATH/build/bin/sedmv"
  assertEquals "$(readlink ~/bin/pidof)" "$FRESH_PATH/build/bin/pidof"
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
  ) > tmp/sandbox/test_parse_fresh_dsl_args.log 2>&1
  echo EXIT_STATUS=$? >> tmp/sandbox/test_parse_fresh_dsl_args.log
  assertFileMatches tmp/sandbox/test_parse_fresh_dsl_args.log
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
