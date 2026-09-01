
SOURCE="$PACKAGE_ROOT/dotfiles"
TARGET="$HOME/"

on_init() {
  log "$(basename $module) initializing..."
}

on_install() {

  if [[ -e "$TARGET/my-neovim" ]]; then
    log "Cleaning '$TARGET/.config/my-neovim'..."
    rm -rf "$TARGET/my-neovim" 
  fi
  log "Stowing '$SOURCE' to '$TARGET'..."
  stow --dir "$SOURCE" -S . -t "$TARGET"

  # echo "linking ~/.config/nvim..." 2>&1 | indent
  # ln -sf ~/.config/my-neovim ~/.config/nvim
}

on_uninstall() {
  warn_badge "Unstowing '$SOURCE' from '$TARGET'..."
  stow --dir "$SOURCE" -D . -t "$TARGET"
}


