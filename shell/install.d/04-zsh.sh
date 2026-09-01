#!/usr/bin/env bash

TARGET="$HOME/.zshrc"
BACKUP="$TARGET.backup"

on_init() {
  log "$(basename $module) initializing..."

  # Modules are sourced in their own subshell, so exiting here skips the
  # install/uninstall hook without failing the run.
  if [[ "$(sys-get-os)" == "nixos" ]]; then
    warn "No need to configure 'zsh' on NixOs." 2>&1 | indent
    exit 0
  fi
}

on_install() {
  if [[ -f "$TARGET" ]]; then
    warn "'$TARGET' exists... backing up to '$BACKUP'..." 2>&1 | indent
    mv "$TARGET" "$BACKUP"
  fi

  log "Overwriting '$TARGET'..."
  echo "source ~/.local/share/$PREFIX/shell/zsh.rc.sh" > "$TARGET"
}

on_uninstall() {
  if [[ -f "$BACKUP" ]]; then
    warn_badge "Restoring '$TARGET' from '$BACKUP'..." 2>&1 | indent
    mv "$BACKUP" "$TARGET"
  elif [[ -f "$TARGET" ]]; then
    # Nothing was backed up, so the file is the one on_install wrote.
    warn_badge "Removing '$TARGET'..." 2>&1 | indent
    rm -f "$TARGET"
  fi
}
