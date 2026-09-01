#!/usr/bin/env bash

SOURCE="$PROJECT_ROOT/hyprland/dotfiles"
TARGET="$HOME/"

on_init() {
  log "$(basename $module) initializing..."
}

on_install() {
  log "Stowing '$SOURCE' to '$TARGET'..."
  stow --dir "$SOURCE" -S . -t "$TARGET"
}

on_uninstall() {
  warn_badge "Unstowing '$SOURCE' from '$TARGET'..."
  stow --dir "$SOURCE" -D . -t "$TARGET"
}


