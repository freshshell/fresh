#!/bin/bash

assert_parse_fresh_dsl_args() {
  (
    set -e
    source bin/fresh
    _dsl_fresh_options # init defaults
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

it_escapes_arguments() {
  (
    set -e
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
    source bin/fresh
    echo y | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_negative() {
  (
    set -e
    source bin/fresh
    echo n | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertFalse 'returns false' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_default() {
  (
    set -e
    source bin/fresh
    echo | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_invalid() {
  (
    set -e
    source bin/fresh
    echo -e "blah\ny" | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

source test/test_helper.sh
