export PATH="tmp/sandbox/bin:$PATH"
export HOME="tmp/sandbox/home"
export FRESH_RCFILE=tmp/sandbox/freshrc
export FRESH_PATH=tmp/sandbox/fresh
export FRESH_LOCAL=tmp/sandbox/dotfiles

setUp() {
  mkdir -p tmp
  if [[ -e tmp/sandbox ]]; then
    rm -rf tmp/sandbox
  fi
  mkdir tmp/sandbox
  mkdir tmp/sandbox/home
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
  mkdir -p tmp/sandbox/bin
  cat > tmp/sandbox/bin/git <<EOF
#!/bin/bash -e
echo cd "$(pwd)" >> tmp/sandbox/git.log
echo git "\$@" >> tmp/sandbox/git.log
case "\$1" in
  clone)
    mkdir "\$3"
    echo test data > "\$3/file"
    ;;
esac
EOF
  chmod +x tmp/sandbox/bin/git
}

source test/support/shunit2
