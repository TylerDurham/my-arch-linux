
#!/usr/bin/env bash

# Keep GNU stow from owning these directories
DIRECTORIES=(
  "$HOME/.local/share/$PREFIX/bin"
  "$HOME/.local/share/$PREFIX/lib/bash"
  "$HOME/.local/share/$PREFIX/shell/hooks/envs"
  "$HOME/.config/$PREFIX"
  "$HOME/.claude/commands"
)

on_init() {
  echo "$(basename $module) initializing..." 2>&1 | indent
}

on_install() {
  echo "$(basename $module) installing..." 2>&1 | indent
  for dir in "${DIRECTORIES[@]}"; do
    echo " - Creating directory at '$dir'..." 2>&1 | indent 
    mkdir -p "$dir"
  done
}

on_uninstall() {
  echo "$(basename $module) uninstalling..." 2>&1 | indent
  for dir in "${DIRECTORIES[@]}"; do
    warn "Removing directory at '$dir'..." 2>&1 | indent
    rm -rf "$dir"
  done
}

