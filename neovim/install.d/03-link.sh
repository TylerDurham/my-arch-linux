
on_init() {
  log "$(basename $module) initializing..."
}

on_install() {
  echo "linking ~/.config/nvim..." 2>&1 | indent
  ln -sf ~/.config/my-neovim ~/.config/nvim
}

on_uninstall() {
  echo "unlinking ~/.config/nvim..." 2>&1 | indent
  rm ~/.config/nvim
}

