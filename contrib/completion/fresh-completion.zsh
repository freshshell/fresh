#compdef fresh

# zsh completion wrapper for fresh
#
# The recommended way to install this script is to add the following fresh line:
#
#   fresh freshshell/fresh contrib/completion/fresh-completion.zsh --file=completion/_fresh
#
# You will also need to add the following line to your zsh config:
#
#   fpath=(~/.fresh/build/completion $fpath)

case $CURRENT in
  2)
    _values 'fresh command' \
      'install[Build shell configuration and relevant symlinks (default)]' \
      'update[Update from source repos and rebuild]' \
      'search[Search the fresh directory]' \
      'edit[Open freshrc for editing]' \
      'help[Show help]'
    ;;
  3)
    case "$words[2]" in
      update|up)
        _values 'fresh sources' $(
          cd ~/.fresh/source
          find * -maxdepth 1 -type d
        )
      ;;
    esac
    ;;
esac
