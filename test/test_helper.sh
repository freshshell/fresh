export FRESH_RCFILE=tmp/sandbox/freshrc
export FRESH_PATH=tmp/sandbox/fresh
export FRESH_LOCAL=tmp/sandbox/dotfiles

setUp() {
  mkdir -p tmp
  if [[ -e tmp/sandbox ]]; then
    rm -rf tmp/sandbox
  fi
  mkdir tmp/sandbox
}

suite() {
  for test_name in `grep '^it_' $0 | cut -d '(' -f 1`; do
    suite_addTest $test_name
  done
}

source test/support/shunit2
