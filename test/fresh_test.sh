it_concatenates_local_shell_files() {
  echo fresh aliases/git >> $FRESH_RCFILE
  echo fresh aliases/ruby >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL/aliases
  echo "alias gs='git status'" >> $FRESH_LOCAL/aliases/git
  echo "alias gl='git log'" >> $FRESH_LOCAL/aliases/git
  echo "alias rake='bundle exec rake'" >> $FRESH_LOCAL/aliases/ruby

  assertTrue 'returns true' bin/fresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="$(bin_path):\$PATH"
alias gs='git status'
alias gl='git log'
alias rake='bundle exec rake'
EOF
}

it_creates_empty_output_with_no_rcfile() {
  assertFalse 'file does not exist before' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  assertTrue 'returns true' bin/fresh
  assertTrue 'file exists after' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="$(bin_path):\$PATH"
EOF
}

it_errors_with_missing_local_file() {
  echo fresh no_such_file >> $FRESH_RCFILE
  assertFalse 'returns false' bin/fresh
}

it_preserves_existing_compiled_file_when_failing() {
  mkdir -p $FRESH_PATH/build
  echo 'existing file' > $FRESH_PATH/build/shell.sh
  cp $FRESH_PATH/build/shell.sh tmp/sandbox/ref_shell.sh

  echo invalid >> $FRESH_RCFILE
  assertFalse 'returns false' bin/fresh

  assertTrue 'file exists' '[ -f "$FRESH_PATH/build/shell.sh" ]'
  diff -U2 tmp/sandbox/ref_shell.sh $FRESH_PATH/build/shell.sh
  assertTrue 'original content exists' $?
}

source test/test_helper.sh
