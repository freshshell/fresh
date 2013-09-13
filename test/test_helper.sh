mkdir -p tmp/sandbox
export ORIG_PATH="$(pwd)"
export SANDBOX_PATH="$(CDPATH= cd tmp/sandbox && pwd)"
export PATH="$SANDBOX_PATH/bin:$PATH"
export HOME="$SANDBOX_PATH/home"
export FRESH_RCFILE="$SANDBOX_PATH/freshrc"
export FRESH_PATH="$SANDBOX_PATH/fresh"
export FRESH_LOCAL="$SANDBOX_PATH/dotfiles"

TEST_NAME="$1"
shift

ERROR_PREFIX=$'\033[4;31mError\033[0m:'

setUp() {
  if [[ -e "$SANDBOX_PATH" ]]; then
    rm -rf "$SANDBOX_PATH"
  fi
  mkdir -p "$SANDBOX_PATH"/{home,bin}
  ln -s "$ORIG_PATH/bin/fresh" "$SANDBOX_PATH/bin/"
  export FRESH_NO_BIN_CHECK=true
  cd "$SANDBOX_PATH"
}

tearDown() {
  cd "$ORIG_PATH"
}

suite() {
  for test_name in `grep '^it_' $0 | cut -d '(' -f 1`; do
    if [[ -z "$TEST_NAME" ]] || echo "$test_name" | grep -q "$TEST_NAME"; then
      suite_addTest $test_name
    fi
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
    shift
    bin/fresh "$@" > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
    assertFalse 'fails to build' $?
  else
    bin/fresh "$@" > "$SANDBOX_PATH/out.log" 2> "$SANDBOX_PATH/err.log"
    assertTrue 'successfully builds' $?
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
    if [ -e .git/commands ]; then
      bash .git/commands
    fi
    if [ -e .git/output ]; then
      cat .git/output
    else
      echo Current branch master is up to date.
    fi
    if [ -e .git/failure ]; then
      exit 1
    fi
    ;;
  show)
    echo test data for "\$2"
    ;;
  ls-tree)
    echo aliases/git.sh
    echo aliases/ruby.sh
    echo ackrc
    echo sedmv
    echo recursive-test/foo
    echo recursive-test/bar
    echo recursive-test/abc/def
    echo hidden-test/foo
    echo hidden-test/.bar
    ;;
  log)
    echo 1234567
    ;;
  config)
    echo git@github.com:repo/name.git
    ;;
  status)
    if [ -e .git/dirty ]; then
      echo ' M some-file'
    fi
    ;;
esac
EOF
  chmod +x $SANDBOX_PATH/bin/git
}

stubCurl() {
  cat > $SANDBOX_PATH/bin/curl <<EOF
#!/bin/bash -e
echo curl >> $SANDBOX_PATH/curl.log
for ARG in "\$@"; do
  echo "\$ARG" >> $SANDBOX_PATH/curl.log
done
EOF
if [[ "$1" == '--fail' ]]; then
shift
  cat >> $SANDBOX_PATH/bin/curl <<EOF
echo "$*" >&2
exit 1
EOF
else
for LINE in "$@"; do
  echo "echo \"$LINE\"" >> $SANDBOX_PATH/bin/curl
done
fi
  chmod +x $SANDBOX_PATH/bin/curl
}

_format_url() {
  echo $'\033[4;34m'"$1"$'\033[0m'
}

source test/support/shunit2
