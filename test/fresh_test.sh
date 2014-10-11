#!/bin/bash

it_links_directory_of_generic_files_for_whole_repo() {
  stubGit
  mkdir -p $FRESH_PATH/source/repo/name/{.git,.hidden-dir,sub} $FRESH_LOCAL

  echo 'fresh repo/name . --file=~/.foo/' >> $FRESH_RCFILE

  echo file1 > $FRESH_PATH/source/repo/name/file1
  echo file2 > $FRESH_PATH/source/repo/name/sub/file2
  touch $FRESH_PATH/source/repo/name/{.git,.hidden-dir}/some-file

  runFresh

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF

  assertEquals "$FRESH_PATH/build/foo" "$(readlink ~/.foo)"

  assertFileMatches $FRESH_PATH/build/foo/file1 <<EOF
file1
EOF
  assertFileMatches $FRESH_PATH/build/foo/sub/file2 <<EOF
file2
EOF

  assertFalse 'git repo is not copied' '[ -e $FRESH_PATH/build/foo/.git ]'
  assertTrue 'hidden dirs are copied' '[ -e $FRESH_PATH/build/foo/.hidden-dir ]'

  assertTrue 'can traverse symlink' '[ -f ~/.foo/file1 ]'
  assertTrue 'can traverse symlink' '[ -f ~/.foo/sub/file2 ]'
}

it_links_directory_of_generic_files_for_whole_repo_with_ref() {
  stubGit
  mkdir -p $FRESH_PATH/source/repo/name/.git $FRESH_LOCAL

  echo 'fresh repo/name . --file=~/.foo/' --ref=abc123 >> $FRESH_RCFILE

  runFresh

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF

  assertEquals "$FRESH_PATH/build/foo" "$(readlink ~/.foo)"

  assertFileMatches $FRESH_PATH/build/foo/ackrc <<EOF
test data for abc123:ackrc
EOF
  assertFileMatches $FRESH_PATH/build/foo/recursive-test/abc/def <<EOF
test data for abc123:recursive-test/abc/def
EOF

  assertTrue 'can traverse symlink' '[ -f ~/.foo/ackrc ]'
  assertTrue 'can traverse symlink' '[ -f ~/.foo/recursive-test/abc/def ]'
}

it_errors_if_trying_to_use_whole_repo_with_invalid_arguments() {
  stubGit
  mkdir -p $FRESH_PATH/source/repo/name/.git $FRESH_LOCAL

  # good
  echo 'fresh repo/name . --file=~/.good/' > $FRESH_RCFILE
  runFresh
  assertFalse 'does not output an error' '[ -s $SANDBOX_PATH/err.log ]'

  # invalid path to --file
  echo 'fresh repo/name . --file=~/.bad-path' > $FRESH_RCFILE
  runFresh fails
  assertFileMatches <(grep Error $SANDBOX_PATH/err.log) <<EOF
$(echo $'\033[4;31mError\033[0m:') Whole repositories require destination to be a directory.
EOF

  # missing path to --file
  echo 'fresh repo/name . --file' > $FRESH_RCFILE
  runFresh fails
  assertFileMatches <(grep Error $SANDBOX_PATH/err.log) <<EOF
$(echo $'\033[4;31mError\033[0m:') Whole repositories require destination to be a directory.
EOF

  # missing --file
  echo 'fresh repo/name .' > $FRESH_RCFILE
  runFresh fails
  assertFileMatches <(grep Error $SANDBOX_PATH/err.log) <<EOF
$(echo $'\033[4;31mError\033[0m:') Whole repositories can only be sourced in file mode.
EOF

  # missing repo
  echo 'fresh . --file=~/.bad-local/' > $FRESH_RCFILE
  runFresh fails
  assertFileMatches <(grep Error $SANDBOX_PATH/err.log) <<EOF
$(echo $'\033[4;31mError\033[0m:') Cannot source whole of local dotfiles.
EOF
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

  assertEquals "$FRESH_PATH/build/bin/sedmv" "$(readlink ~/bin/sedmv)"
  assertEquals "$FRESH_PATH/build/bin/pidof" "$(readlink ~/bin/pidof)"
  assertEquals "$FRESH_PATH/build/bin/gemdiff" "$(readlink ~/bin/scripts/gemdiff)"
}

it_warns_if_concatenating_bin_files() {
  echo 'FRESH_NO_BIN_CONFLICT_CHECK=true' >> $FRESH_RCFILE
  echo 'fresh gemdiff --bin' >> $FRESH_RCFILE
  echo 'fresh scripts/gemdiff --bin' >> $FRESH_RCFILE
  echo 'unset FRESH_NO_BIN_CONFLICT_CHECK' >> $FRESH_RCFILE
  echo 'fresh sedmv --bin' >> $FRESH_RCFILE
  echo 'fresh scripts/sedmv --bin' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/scripts
  touch $FRESH_LOCAL/{scripts/sedmv,sedmv,scripts/gemdiff,gemdiff}

  runFresh

  assertEquals "$FRESH_PATH/build/bin/sedmv" "$(readlink ~/bin/sedmv)"

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
$(echo $'\033[1;33mNote\033[0m:') Multiple sources concatenated into a single bin file.
$FRESH_RCFILE:6: fresh scripts/sedmv --bin

Typically bin files should not be concatenated together into one file.
"bin/sedmv" may not function as expected.

To disable this warning, add \`FRESH_NO_BIN_CONFLICT_CHECK=true\` in your freshrc file.

$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF

assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_runs_filters_on_files() {
  mkdir -p $FRESH_LOCAL
  echo "foo other_username bar" > $FRESH_LOCAL/aliases
  echo "fresh aliases --filter='sed s/other_username/my_username/ | tr _ -'" > $FRESH_RCFILE

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases # sed s/other_username/my_username/ | tr _ -

foo my-username bar
EOF
}

it_runs_filters_on_files_locked_to_a_ref() {
  mkdir -p $FRESH_LOCAL
  echo "fresh aliases/git.sh --ref=abc1237 --filter='sed s/test/TEST/'" > $FRESH_RCFILE

  stubGit

  runFresh

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"

# fresh: aliases/git.sh @ abc1237 # sed s/test/TEST/

TEST data for abc1237:aliases/git.sh
EOF
}

it_errors_when_linking_bin_files_with_relative_paths() {
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foobar

  echo 'fresh foobar --bin=foobar' > $FRESH_RCFILE
  runFresh fails

  echo 'fresh foobar --bin=../foobar' > $FRESH_RCFILE
  runFresh fails
}

it_errors_if_existing_symlink_for_file_does_not_point_to_a_fresh_path() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  ln -s /dev/null ~/.pryrc

  runFresh fails

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX $HOME/.pryrc already exists (pointing to /dev/null).
$FRESH_RCFILE:1: fresh pryrc --file

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF

  assertEquals /dev/null "$(readlink ~/.pryrc)"
}

it_errors_if_existing_symlink_for_bin_does_not_point_to_a_fresh_path() {
  echo fresh bin/sedmv --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin ~/bin
  touch $FRESH_LOCAL/bin/sedmv
  ln -s /dev/null ~/bin/sedmv

  runFresh fails

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX $HOME/bin/sedmv already exists (pointing to /dev/null).
$FRESH_RCFILE:1: fresh bin/sedmv --bin

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF

  assertEquals /dev/null "$(readlink ~/bin/sedmv)"
}

it_errors_if_file_exists() {
  echo 'fresh pryrc --file' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  touch "$SANDBOX_PATH/home/.pryrc"

  runFresh fails

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX $HOME/.pryrc already exists.
$FRESH_RCFILE:1: fresh pryrc --file
EOF
}

it_errors_if_directory_is_not_writable() {
  echo 'fresh pryrc --file' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  chmod -w "$SANDBOX_PATH/home"

  runFresh fails

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Could not create $HOME/.pryrc. Do you have permission?
$FRESH_RCFILE:1: fresh pryrc --file
EOF
}

it_errors_if_directory_cannot_be_created() {
  echo 'fresh foo --file=~/.config/foo' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/foo
  chmod -w "$SANDBOX_PATH/home"

  runFresh fails

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Could not create $HOME/.config/foo. Do you have permission?
$FRESH_RCFILE:1: fresh foo --file=~/.config/foo
EOF
}

it_does_not_error_for_symlinks_created_by_fresh() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  echo fresh bin/sedmv --bin >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin
  touch $FRESH_LOCAL/pryrc
  touch $FRESH_LOCAL/bin/sedmv

  runFresh # build symlinks
  runFresh # run fresh again to check symlinks
}

it_replaces_old_symlinks_pointing_inside_the_fresh_build_directory() {
  echo fresh pryrc --file >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/build $FRESH_LOCAL
  touch $FRESH_LOCAL/pryrc
  ln -s $FRESH_PATH/build/pryrc-old-name ~/.pryrc

  runFresh
  assertEquals $FRESH_PATH/build/pryrc "$(readlink ~/.pryrc)"
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
  stubGit

  mkdir -p $FRESH_LOCAL
  echo 'fresh bad-file' > $FRESH_RCFILE

  runFresh fails
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/out.log ]'

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Could not find "bad-file" source file.
$FRESH_RCFILE:1: fresh bad-file

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF

  mkdir -p $FRESH_LOCAL
  echo 'fresh repo/name bad-file --ref=abc123' > $FRESH_RCFILE

  runFresh fails
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/out.log ]'

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Could not find "bad-file" source file.
$FRESH_RCFILE:1: fresh repo/name bad-file --ref=abc123

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
Have a look at the repo: <$(_format_url https://github.com/repo/name)>
EOF

  mkdir -p $FRESH_LOCAL
  echo 'fresh repo/name some-file --blah' > $FRESH_RCFILE

  runFresh fails
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/out.log ]'

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Unknown option: --blah
$FRESH_RCFILE:1: fresh repo/name some-file --blah

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
Have a look at the repo: <$(_format_url https://github.com/repo/name)>
EOF

  echo 'source ~/.freshrc.local' > $FRESH_RCFILE
cat > $SANDBOX_PATH/home/.freshrc.local <<EOF
# local customisations

fresh pry.rb --file=~/.pryrc # ruby
fresh some-other-file
EOF

  runFresh fails
  assertFalse 'does not output to stdout' '[ -s $SANDBOX_PATH/out.log ]'

  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Could not find "pry.rb" source file.
~/.freshrc.local:3: fresh pry.rb --file=~/.pryrc # ruby

You may need to run \`fresh update\` if you're adding a new line,
or the file you're referencing may have moved or been deleted.
EOF
}

it_updates_fresh_files() {
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git
  stubGit

  runFresh update
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/other_repo/other_name
git pull --rebase
cd $FRESH_PATH/source/repo/name
git pull --rebase
EOF
}

it_updates_fresh_files_for_a_specified_github_user() {
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles/.git
  mkdir -p $FRESH_PATH/source/twe4ked/scripts/.git
  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  stubGit

  runFresh update twe4ked
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/twe4ked/dotfiles
git pull --rebase
cd $FRESH_PATH/source/twe4ked/scripts
git pull --rebase
EOF
}

it_updates_fresh_files_for_a_specified_github_repo() {
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles/.git
  mkdir -p $FRESH_PATH/source/twe4ked/dotfiles-old/.git
  mkdir -p $FRESH_PATH/source/twe4ked/scripts/.git
  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  stubGit

  runFresh update twe4ked/dotfiles
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/twe4ked/dotfiles
git pull --rebase
EOF
}

it_updates_local_repo_with_no_args() {
  mkdir -p $FRESH_LOCAL/.git
  mkdir -p $FRESH_PATH/source/freshshell/fresh/.git
  stubGit

  runFresh update

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_LOCAL
git rev-parse @{u}
cd $FRESH_LOCAL
git status --porcelain
cd $FRESH_LOCAL
git pull --rebase
cd $FRESH_PATH/source/freshshell/fresh
git pull --rebase
EOF
}

it_only_updates_local_repo_with_local_arg() {
  mkdir -p $FRESH_LOCAL/.git
  mkdir -p $FRESH_PATH/source/freshshell/fresh/.git
  stubGit

  runFresh update --local

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_LOCAL
git rev-parse @{u}
cd $FRESH_LOCAL
git status --porcelain
cd $FRESH_LOCAL
git pull --rebase
EOF
}

it_does_not_update_local_with_other_args() {
  mkdir -p $FRESH_LOCAL/.git
  mkdir -p $FRESH_PATH/source/freshshell/fresh/.git
  stubGit

  runFresh update freshshell

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/freshshell/fresh
git pull --rebase
EOF
}

it_does_not_update_local_dirty_local() {
  mkdir -p $FRESH_LOCAL/.git
  touch $FRESH_LOCAL/.git/dirty
  stubGit

  runFresh fails update --local

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_LOCAL
git rev-parse @{u}
cd $FRESH_LOCAL
git status --porcelain
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
$(echo $'\033[1;33mNote\033[0m:') Not updating $FRESH_LOCAL because it has uncommitted changes.
EOF
}


it_errors_if_no_matching_sources_to_update() {
  mkdir -p $FRESH_PATH/source

  runFresh fails update foobar

  assertFileMatches "$SANDBOX_PATH/err.log" <<EOF
$ERROR_PREFIX No matching sources found.
EOF
}

it_errors_if_more_than_one_argument_is_passed_to_update() {
  mkdir -p $FRESH_PATH/source

  runFresh fails update twe4ked dotfiles

  assertFileMatches "$SANDBOX_PATH/err.log" <<EOF
$ERROR_PREFIX Invalid arguments.

usage: fresh update <filter>

    The filter can be either a GitHub username or username/repo.
EOF
}

it_shows_progress_when_updating_remote() {
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git
  stubGit

  runFresh update
  assertTrue 'outputs "repo/name"' 'grep -qxF "* Updating repo/name" $SANDBOX_PATH/out.log'
  assertTrue 'shows git output with prefix' 'grep -qxF "| Current branch master is up to date." $SANDBOX_PATH/out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_progress_when_updating_local() {
  mkdir -p $FRESH_LOCAL/.git
  stubGit

  runFresh update --local
  assertTrue 'outputs local message' 'grep -qxF "* Updating local files" $SANDBOX_PATH/out.log'
  assertTrue 'shows git output with prefix' 'grep -qxF "| Current branch master is up to date." $SANDBOX_PATH/out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_a_github_compare_url_when_updating_remote() {
  stubGit

  mkdir -p $FRESH_PATH/source/jasoncodes/dotfiles/.git
  cat > $FRESH_PATH/source/jasoncodes/dotfiles/.git/output <<EOF
From https://github.com/jasoncodes/dotfiles
   47ad84c..57b8b2b  master     -> origin/master
First, rewinding head to replay your work on top of it...
Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
EOF

  runFresh update
  assertTrue 'shows GitHub compare URL' 'grep -qF "https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b" $SANDBOX_PATH/out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_a_github_compare_url_when_updating_local() {
  stubGit

  mkdir -p $FRESH_LOCAL/.git
  cat > $FRESH_LOCAL/.git/output <<EOF
From https://github.com/jasoncodes/dotfiles
   47ad84c..57b8b2b  master     -> origin/master
First, rewinding head to replay your work on top of it...
Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
EOF

  runFresh update --local
  cat $SANDBOX_PATH/err.log
  assertTrue 'shows GitHub compare URL' 'grep -qF "https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b" $SANDBOX_PATH/out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_shows_no_url_when_updating_other_repos() {
  stubGit

  mkdir -p $FRESH_PATH/source/gitorious.org/willgit-mainline/.git
  cat > $FRESH_PATH/source/gitorious.org/willgit-mainline/.git/output <<EOF
From git://gitorious.org/willgit/mainline
   67444ba..a2322a5  master     -> origin/master
EOF

  runFresh update
  assertFalse 'does not output a compare URL' 'egrep -q "https?://" $SANDBOX_PATH/out.log'
  assertFalse 'does not output to stderr' '[ -s $SANDBOX_PATH/err.log ]'
}

it_logs_update_output() {
  mkdir -p $FRESH_LOCAL/.git
  mkdir -p $FRESH_PATH/source/repo/name/.git
  mkdir -p $FRESH_PATH/source/other_repo/other_name/.git

  stubGit
  runFresh update
  assertTrue 'creates a log file' '[[ "$(find "$FRESH_PATH/logs" -type f | wc -l)" -eq 1 ]]'
  assertTrue 'log file name' 'find "$FRESH_PATH/logs" -type f | egrep -q "/logs/update-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\\.log$"'

  assertFileMatches $FRESH_PATH/logs/* <<EOF
* Updating local files
| Current branch master is up to date.
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

  runFresh fails update
  assertTrue 'output does not exist' '[ ! -f "$FRESH_PATH/build/shell.sh" ]'
}

it_builds_after_update_with_latest_binary() {
  echo 'fresh bin/\* --bin' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin $FRESH_PATH/source

  mkdir -p $FRESH_PATH/source/freshshell/fresh/.git
  stubGit

  echo "echo new >> \"$SANDBOX_PATH/fresh.log\"" >> $FRESH_LOCAL/bin/fresh
  echo "echo bad >> \"$SANDBOX_PATH/fresh.log\"" >> $FRESH_LOCAL/bin/other

  runFresh update

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
  runFresh fails
  assertFalse 'does not build' '[ -d $FRESH_PATH/build ]'
  assertTrue 'mentions solution' 'grep -q "fresh freshshell/fresh bin/fresh --bin" $SANDBOX_PATH/err.log'
}

it_allows_bin_fresh_error_to_be_disabled() {
  touch $FRESH_RCFILE

  export FRESH_NO_BIN_CHECK=true
  runFresh
}

it_allows_default_bin_path_to_be_configured() {
  echo "FRESH_BIN_PATH=\"\$HOME/Applications/bin\"" >> $FRESH_RCFILE
  echo "fresh bin/fresh --bin" >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL/bin
  echo "test file" > $FRESH_LOCAL/bin/fresh

  runFresh

  assertTrue 'file exists after' '[ -f "$HOME/Applications/bin/fresh" ]'
  assertEquals "$FRESH_PATH/build/bin/fresh" "$(readlink ~/Applications/bin/fresh)"
  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export PATH="\$HOME/Applications/bin:\$PATH"
export FRESH_PATH="$FRESH_PATH"
EOF
  assertFileMatches "$HOME/Applications/bin/fresh" <<EOF
test file
EOF
}

it_path_export_to_be_disabled() {
  export FRESH_NO_PATH_EXPORT=1
  runFresh
  unset FRESH_NO_PATH_EXPORT

  assertFileMatches $FRESH_PATH/build/shell.sh <<EOF
export FRESH_PATH="$FRESH_PATH"
EOF
}

it_runs_fresh_after_build() {
  echo "fresh_after_build() { echo test after_build; }" >> $FRESH_RCFILE

  runFresh

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
test after_build
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
}

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

it_searches_directory_for_keywords() {
  stubCurl "foo" "bar baz"
  runFresh search foo bar
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
  runFresh fails search
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX No search query given.
EOF
  assertFalse 'curl was not invoked' '[ -e "$SANDBOX_PATH/curl.log" ]'
}

it_shows_error_if_search_has_no_results() {
  stubCurl
  runFresh fails search crap
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
  runFresh fails search blah
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

it_cleans_dead_symlinks_from_home_and_bin() {
  echo 'fresh alive --file' >> $FRESH_RCFILE
  echo 'fresh alive --bin' >> $FRESH_RCFILE
  echo 'fresh dead --file' >> $FRESH_RCFILE
  echo 'fresh dead --bin' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{alive,dead}
  runFresh
  rm -f $FRESH_PATH/build/{dead,bin/dead}
  ln -s no_such_file ~/.other
  ln -s no_such_file ~/bin/other

  runFresh clean

  assertTrue '~/.alive still exists' '[ -L ~/.alive ]'
  assertTrue '~/bin/alive still exists' '[ -L ~/bin/alive ]'
  assertFalse '~/.dead no longer exists' '[ -L ~/.dead ]'
  assertFalse '~/bin/dead no longer exists' '[ -L ~/bin/dead ]'
  assertTrue '~/.other still exists' '[ -L ~/.other ]'
  assertTrue '~/bin/other still exists' '[ -L ~/bin/other ]'

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Removing ~/.dead
Removing ~/bin/dead
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_cleans_repositories_no_longer_referenced_by_freshrc() {
  echo 'fresh foo/bar file' >> $FRESH_RCFILE
  echo 'fresh git://example.com/foobar.git file' >> $FRESH_RCFILE
  mkdir -p $FRESH_PATH/source/{foo/bar,foo/baz,abc/def,example.com/foobar}/.git

  runFresh clean

  assertTrue 'foo/bar still exists' '[ -d "$FRESH_PATH/source/foo/bar/.git" ]'
  assertFalse 'foo/baz was cleaned' '[ -d "$FRESH_PATH/source/foo/baz/.git" ]'
  assertFalse 'abc/def was cleaned' '[ -d "$FRESH_PATH/source/abc/def" ]'
  assertFalse 'abc (empty parent) was cleaned' '[ -d "$FRESH_PATH/source/abc" ]'

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Removing source abc/def
Removing source foo/baz
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_shows_sources_for_fresh_lines() {
  echo 'fresh foo/bar aliases/*' >> $FRESH_RCFILE
  echo 'fresh foo/bar sedmv --bin --ref=abc123' >> $FRESH_RCFILE
  echo 'fresh local-file' >> $FRESH_RCFILE

  mkdir -p $FRESH_PATH/source/foo/bar/aliases/
  touch $FRESH_PATH/source/foo/bar/aliases/{git.sh,ruby.sh}
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/local-file

  stubGit

  runFresh show

  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH/fresh/source/foo/bar
git log --pretty=%H -n 1 -- aliases/git.sh
cd $SANDBOX_PATH/fresh/source/foo/bar
git log --pretty=%H -n 1 -- aliases/ruby.sh
cd $SANDBOX_PATH/fresh/source/foo/bar
git ls-tree -r --name-only abc123
EOF

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
fresh foo/bar aliases/\\*
<$(_format_url https://github.com/foo/bar/blob/1234567/aliases/git.sh)>
<$(_format_url https://github.com/foo/bar/blob/1234567/aliases/ruby.sh)>

fresh foo/bar sedmv --bin --ref=abc123
<$(_format_url https://github.com/foo/bar/blob/abc123/sedmv)>

fresh local-file
<$(_format_url $FRESH_LOCAL/local-file)>
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_shows_git_urls_for_non_github_repos() {
  echo fresh git://example.com/one/two.git file >> $FRESH_RCFILE

  stubGit

  runFresh show

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
fresh git://example.com/one/two.git file
<$(_format_url git://example.com/one/two.git)>
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
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

it_adds_lines_to_freshrc_for_local_files() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new\ file}

  yes | runFresh 'new file'
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
fresh new\\ file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh new\\ file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh new\\ file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_for_new_remotes() {
  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH
git clone https://github.com/user/repo $FRESH_PATH/source/user/repo
EOF
}

it_adds_lines_to_freshrc_for_new_remotes_by_url() {
  stubGit

  yes | runFresh https://github.com/user/repo/blob/master/file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH
git clone https://github.com/user/repo $FRESH_PATH/source/user/repo
EOF
}

it_adds_lines_to_freshrc_for_existing_remotes_and_updates_if_the_file_does_not_exist() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  echo "touch \"$FRESH_PATH/source/user/repo/file\"" > "$FRESH_PATH/source/user/repo/.git/commands"

  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
* Updating user/repo
| Current branch master is up to date.
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/user/repo
git pull --rebase
EOF
}

it_does_not_add_lines_to_freshrc_if_declined() {
  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new}

  yes n | runFresh new
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh new\` to $FRESH_RCFILE [Y/n]? $(echo $'\033[1;33mNote\033[0m:') Use \`fresh edit\` to manually edit your $FRESH_RCFILE.
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_without_updating_existing_repo_if_the_file_exists() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFalse 'did not run git' '[ -f $SANDBOX_PATH/git.log ]'
}

parse_fresh_add_args() {
  yes n | runFresh "$@"
  assertTrue "line matches" "grep -q '^Add \`fresh .*\` to' < $SANDBOX_PATH/out.log"
  sed -e 's/^Add `//' -e 's/`.*$//' $SANDBOX_PATH/out.log
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_from_github_urls() {
  # auto add --bin
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/master/bin/catacomb)"

  # --bin will not duplicate
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/master/bin/catacomb --bin)"

  # works out --ref
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin --ref=a62f448" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/a62f448/bin/catacomb)"

  # auto add --file
  assertEquals "fresh twe4ked/dotfiles config/pryrc --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc)"

  # --file will not duplicate
  assertEquals "fresh twe4ked/dotfiles config/pryrc --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --file)"

  # auto add --file preserves other options
  assertEquals "fresh twe4ked/dotfiles config/pryrc --marker --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --marker)"

  # doesn't add --bin or --file to other files
  assertEquals "fresh twe4ked/dotfiles shell/aliases/git.sh" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/shell/aliases/git.sh)"
}

it_edits_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  assertEquals "$HOME/.freshrc" "$(EDITOR=echo fresh edit)"
}

it_edits_linked_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  mkdir -p ~/.dotfiles/
  touch ~/.dotfiles/freshrc
  ln -s ~/.dotfiles/freshrc ~/.freshrc
  assertEquals "$HOME/.dotfiles/freshrc" "$(EDITOR=echo fresh edit)"
}

it_edits_relative_linked_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  mkdir -p ~/.dotfiles/
  touch ~/.dotfiles/freshrc
  ln -s .dotfiles/freshrc ~/.freshrc
  assertEquals "$HOME/.dotfiles/freshrc" "$(EDITOR=echo fresh edit)"
}

it_applies_fresh_options_to_multiple_lines() {
  echo 'fresh-options --file=~/.vimrc --marker=\"' >> $FRESH_RCFILE
  echo "fresh mappings.vim --filter='tr a x'" >> $FRESH_RCFILE
  echo "fresh autocmds.vim" >> $FRESH_RCFILE
  echo "fresh-options" >> $FRESH_RCFILE
  echo "fresh zshrc --file" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL
  echo "mappings" >> $FRESH_LOCAL/mappings.vim
  echo "autocmds" >> $FRESH_LOCAL/autocmds.vim
  echo "zsh config" >> $FRESH_LOCAL/zshrc

  runFresh

  assertFileMatches $FRESH_PATH/build/vimrc <<EOF
" fresh: mappings.vim # tr a x

mxppings

" fresh: autocmds.vim

autocmds
EOF

  assertFileMatches $FRESH_PATH/build/zshrc <<EOF
zsh config
EOF
}

it_runs_subcommands() {
  bin="$SANDBOX_PATH/bin/fresh-foo"
  echo "echo foobar" > $bin
  chmod +x $bin

  runFresh foo

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
foobar
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_errors_for_unknown_commands() {
  runFresh fails foo
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Unknown command: foo
EOF
}

source test/test_helper.sh
