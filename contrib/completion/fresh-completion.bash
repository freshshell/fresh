# bash completion wrapper for fresh
#
# The recommended way to install this script is to add the following fresh line:
#
#   fresh freshshell/fresh contrib/completion/fresh-completion.bash

_fresh() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local COMMANDS="install update search edit help"
  COMPREPLY=( $( compgen -W "$COMMANDS" -- "$cur" ) )
}

complete -F _fresh fresh
