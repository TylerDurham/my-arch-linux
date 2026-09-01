#!/usr/bin/env bash

# Keep GNU stow from owning these directories
DIRECTORIES=(
  "$HOME/.local/share/$PREFIX/bin"
  "$HOME/.local/share/$PREFIX/lib/bash"
  "$HOME/.local/share/$PREFIX/shell/hooks/"{envs,boot}
  "$HOME/.config/$PREFIX"
  "$HOME/.claude/commands"
)

on_init() {
  log "$(basename $module) initializing..." 2>&1 | indent
}

on_install() {
  for dir in "${DIRECTORIES[@]}"; do
    log "Creating directory at '$dir'..." 2>&1 | indent 
    mkdir -p "$dir"
  done
}

on_uninstall() {
  for dir in "${DIRECTORIES[@]}"; do
    warn_badge "Removing directory at '$dir'..." 2>&1 | indent
    rm -rf "$dir"
  done
}

on_completed() {
  log "$(basename $module) completed!" 2>&1 | indent
}
