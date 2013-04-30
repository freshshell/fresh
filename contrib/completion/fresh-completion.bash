# bash completion wrapper for fresh
#
# The recommended way to install this script is to add the following fresh line:
#
#   fresh freshshell/fresh contrib/completion/fresh-completion.bash

_fresh() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  if [[ $COMP_CWORD == 1 ]]; then
    local WORDS="$(fresh commands | cut -d ' ' -f 1)"
  elif [[ $COMP_CWORD == 2 ]] && [[ "${COMP_WORDS[1]}" =~ ^update$|^up$ ]]; then
    local WORDS="$(
      cd "$FRESH_PATH/source"
      if ! [[ -d "$cur" ]]; then
        find * -maxdepth 0 -type d | sort
      fi
      find * -maxdepth 1 -mindepth 1 -type d | sort
    )"
  else
    local WORDS=""
  fi
  COMPREPLY=( $( compgen -W "$WORDS" -- "$cur" ) )
}

complete -F _fresh fresh
