#!/bin/bash

it_concatenates_local_shell_files() {
  echo fresh aliases/git >> $FRESH_RCFILE
  echo fresh aliases/ruby >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/aliases
  echo "alias gs='git status'" >> $FRESH_LOCAL/aliases/git
  echo "alias gl='git log'" >> $FRESH_LOCAL/aliases/git
  echo "alias rake='bundle exec rake'" >> $FRESH_LOCAL/aliases/ruby

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="$(bin_path):\$PATH"
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
export PATH="$(bin_path):\$PATH"
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

it_copies_files_from_cloned_repos() {
  echo fresh repo/name file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/repo/name
  echo remote content > $FRESH_PATH/source/repo/name/file

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="$(bin_path):\$PATH"
remote content
EOF
}

source test/test_helper.sh
