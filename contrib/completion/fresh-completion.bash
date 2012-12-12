# bash completion wrapper for fresh
#
# The recommended way to install this script is to add the following fresh line:
#
#   fresh freshshell/fresh contrib/completion/fresh-completion.bash

_fresh() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  if [[ $COMP_CWORD == 1 ]]; then
    local WORDS="install update search edit help"
  else
    local WORDS=""
  fi
  COMPREPLY=( $( compgen -W "$WORDS" -- "$cur" ) )
}

complete -F _fresh fresh
