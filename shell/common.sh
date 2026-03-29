if [ -n "${DOTFILES_COMMON_SH_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
export DOTFILES_COMMON_SH_LOADED=1

if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

append_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

[ -d "$HOME/.nix-profile/bin" ] && prepend_path "$HOME/.nix-profile/bin"
[ -d "$HOME/bin" ] && prepend_path "$HOME/bin"
[ -d "$HOME/.local/bin" ] && prepend_path "$HOME/.local/bin"
[ -d "$HOME/.lmstudio/bin" ] && append_path "$HOME/.lmstudio/bin"
[ -d "$HOME/.bun/bin" ] && append_path "$HOME/.bun/bin"
export PATH

alias dots='cd "$DOTFILES_DIR"'
alias hms='hm-switch'
alias hme='${EDITOR:-vi} "$DOTFILES_DIR/nix/home.nix"'
