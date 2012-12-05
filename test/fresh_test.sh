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

# fresh: repo/name file

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

it_builds_generic_files() {
  echo 'fresh lib/tmux.conf --file' >> $FRESH_RCFILE
  echo 'fresh lib/pryrc.rb --file=~/.pryrc --marker' >> $FRESH_RCFILE
  echo 'fresh config/git/colors --file=~/.gitconfig' >> $FRESH_RCFILE
  echo 'fresh config/git/rebase --file=~/.gitconfig' >> $FRESH_RCFILE
  echo "fresh config/*.vim --file=~/.vimrc --marker='\"'" >> $FRESH_RCFILE
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

  assertEquals "$(readlink ~/.tmux.conf)" "$FRESH_PATH/build/tmux.conf"
  assertEquals "$(readlink ~/.pryrc)" "$FRESH_PATH/build/pryrc"
  assertEquals "$(readlink ~/.gitconfig)" "$FRESH_PATH/build/gitconfig"
  assertEquals "$(readlink ~/.vim/colors/bclear.vim)" "$FRESH_PATH/build/bclear.vim"
  assertEquals "$(readlink ~/a\ path/with\ spaces)" "$FRESH_PATH/build/with spaces"
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

  assertEquals "$(readlink ~/bin/sedmv)" "$FRESH_PATH/build/bin/sedmv"
  assertEquals "$(readlink ~/bin/pidof)" "$FRESH_PATH/build/bin/pidof"
  assertEquals "$(readlink ~/bin/scripts/gemdiff)" "$FRESH_PATH/build/bin/gemdiff"
}

it_errors_when_linking_bin_files_with_relative_paths() {
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foobar

  echo 'fresh foobar --bin=foobar' > $FRESH_RCFILE
  runFresh fails

  echo 'fresh foobar --bin=../foobar' > $FRESH_RCFILE
  runFresh fails
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

it_shows_source_of_errors() {
  mkdir -p $FRESH_LOCAL
  echo 'fresh bad-file' > $FRESH_RCFILE

  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/fresh_out.log ]'

  assertFileMatches $SANDBOX_PATH/fresh_err.log <<EOF
$ERROR_PREFIX Could not find "bad-file" source file.
$FRESH_RCFILE:1: fresh bad-file
EOF

  mkdir -p $FRESH_LOCAL
  echo 'fresh some-file --blah' > $FRESH_RCFILE

  bin/fresh > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertFalse 'returns non-zero' $?
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/fresh_out.log ]'

  assertFileMatches $SANDBOX_PATH/fresh_err.log <<EOF
$ERROR_PREFIX Unknown option: --blah
$FRESH_RCFILE:1: fresh some-file --blah
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
From http://github.com/jasoncodes/dotfiles
   47ad84c..57b8b2b  master     -> origin/master
First, rewinding head to replay your work on top of it...
Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
EOF

  bin/fresh update > "$SANDBOX_PATH/fresh_out.log" 2> "$SANDBOX_PATH/fresh_err.log"
  assertTrue 'successfully updates' $?
  assertTrue 'shows GitHub compare URL' 'grep -qF "https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b" $SANDBOX_PATH/fresh_out.log'
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

test_parse_fresh_dsl_args() {
  (
    set -e
    __FRESH_TEST_MODE=1
    source bin/fresh
    parse_fresh_dsl_args "$@" > $SANDBOX_PATH/test_parse_fresh_dsl_args.out
    echo REPO_NAME="$REPO_NAME"
    echo FILE_NAME="$FILE_NAME"
    echo MODE="$MODE"
    echo MODE_ARG="$MODE_ARG"
    echo REF="$REF"
    echo MARKER="$MARKER"
  ) > $SANDBOX_PATH/test_parse_fresh_dsl_args.log 2>&1
  echo EXIT_STATUS=$? >> $SANDBOX_PATH/test_parse_fresh_dsl_args.log
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.out < /dev/null
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.log
}

it_parses_fresh_dsl_args() {
  test_parse_fresh_dsl_args aliases/git.sh <<EOF
REPO_NAME=
FILE_NAME=aliases/git.sh
MODE=
MODE_ARG=
REF=
MARKER=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=
MARKER=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args jasoncodes/dotfiles .gitconfig --file <<EOF
REPO_NAME=jasoncodes/dotfiles
FILE_NAME=.gitconfig
MODE=file
MODE_ARG=
REF=
MARKER=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args sedmv --bin <<EOF
REPO_NAME=
FILE_NAME=sedmv
MODE=bin
MODE_ARG=
REF=
MARKER=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args scripts/pidof.sh --bin=~/bin/pidof <<EOF
REPO_NAME=
FILE_NAME=scripts/pidof.sh
MODE=bin
MODE_ARG=~/bin/pidof
REF=
MARKER=
EXIT_STATUS=0
EOF

  test_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf --ref=abc1237 <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=abc1237
MARKER=
EXIT_STATUS=0
EOF

test_parse_fresh_dsl_args tmux.conf --file --marker <<EOF
REPO_NAME=
FILE_NAME=tmux.conf
MODE=file
MODE_ARG=
REF=
MARKER=#
EXIT_STATUS=0
EOF

test_parse_fresh_dsl_args vimrc --file --marker='"' <<EOF
REPO_NAME=
FILE_NAME=vimrc
MODE=file
MODE_ARG=
REF=
MARKER="
EXIT_STATUS=0
EOF

test_parse_fresh_dsl_args foo --file --marker= <<EOF
$ERROR_PREFIX Marker not specified.
EXIT_STATUS=1
EOF

test_parse_fresh_dsl_args foo --bin --marker <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

test_parse_fresh_dsl_args foo --marker=';' <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args foo --file --ref <<EOF
$ERROR_PREFIX You must specify a Git reference.
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args foo --file --bin <<EOF
$ERROR_PREFIX Cannot have more than one mode.
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args <<EOF
$ERROR_PREFIX Filename is required
EXIT_STATUS=1
EOF

  test_parse_fresh_dsl_args foo bar baz <<EOF
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

source test/test_helper.sh
