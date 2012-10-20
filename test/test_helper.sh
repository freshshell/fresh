mkdir -p tmp/sandbox
export SANDBOX_PATH="$(CDPATH= cd tmp/sandbox && pwd)"
export PATH="$SANDBOX_PATH/bin:$PATH"
export HOME="$SANDBOX_PATH/home"
export FRESH_RCFILE="$SANDBOX_PATH/freshrc"
export FRESH_PATH="$SANDBOX_PATH/fresh"
export FRESH_LOCAL="$SANDBOX_PATH/dotfiles"

setUp() {
  if [[ -e "$SANDBOX_PATH" ]]; then
    rm -rf "$SANDBOX_PATH"
  fi
  mkdir -p "$SANDBOX_PATH"/{home,bin}
}

suite() {
  for test_name in `grep '^it_' $0 | cut -d '(' -f 1`; do
    suite_addTest $test_name
  done
}

# Usage:
#
#   assertFileMatches FILE <<EOF
#   content
#   EOF
assertFileMatches() {
  diff -U2 <(cat) "$1"
  assertTrue "$1 matches" $?
}

runFresh() {
  if [ "$1" == 'fails' ]; then
    assertFalse 'fails to build' bin/fresh
  else
    assertTrue 'successfully builds' bin/fresh
  fi
}

stubGit() {
  cat > $SANDBOX_PATH/bin/git <<EOF
#!/bin/bash -e
echo cd "\$(pwd)" >> $SANDBOX_PATH/git.log
echo git "\$@" >> $SANDBOX_PATH/git.log
case "\$1" in
  clone)
    mkdir "\$3"
    echo test data > "\$3/file"
    ;;
  pull)
    if [ -e .git/failure ]; then
      exit 1
    fi
    ;;
esac
EOF
  chmod +x $SANDBOX_PATH/bin/git
}

source test/support/shunit2
