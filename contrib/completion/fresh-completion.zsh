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
    eval "$(
      printf _values
      printf " %q" "fresh command"
      fresh commands | sed -e 's/^\([^ ]*\)[^#]*# \(.*\)$/\1[\2]/' | while read LINE; do
        printf " %q" "$LINE"
      done
    )"
    ;;
  3)
    case "$words[2]" in
      update|up)
        _values 'fresh sources' $(
          cd "$FRESH_PATH/source"
          find * -maxdepth 1 -type d
        )
      ;;
    esac
    ;;
esac
