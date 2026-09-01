#!/usr/bin/env bash

SOURCE="$(git rev-parse --show-toplevel)/shell/dotfiles"
TARGET="$HOME/"

on_init() {
  echo "$(basename $module) initializing..." 2>&1 | indent
}

on_install() {
  echo "Stowing '$SOURCE' to '$TARGET'..." 2>&1 | indent
  stow --dir "$SOURCE" -S . -t "$TARGET"
}

on_uninstall() {
  warn_badge "Unstowing '$SOURCE' from '$TARGET'..." 2>&1 | indent
  stow --dir "$SOURCE" -D . -t "$TARGET"
}

