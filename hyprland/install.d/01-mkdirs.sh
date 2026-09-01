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
  log "$(basename $module) initializing..."
}

on_install() {
  log "$(basename $module) installing..."
  for dir in "${DIRECTORIES[@]}"; do
    log "Creating directory at '$dir'..."
    mkdir -p "$dir"
  done
}

on_uninstall() {
  log "$(basename $module) uninstalling..."
  for dir in "${DIRECTORIES[@]}"; do
    warn "Removing directory at '$dir'..."
    rm -rf "$dir"
  done
}

