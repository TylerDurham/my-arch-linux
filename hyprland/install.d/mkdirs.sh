#!/usr/bin/env bash

source "$(git rev-parse --show-toplevel)/install.d/envs.sh"

init "$@"

# Keep GNU stow from owning these directories
DIRECTORIES=(
  "$HOME/.local/share/$PREFIX/bin"
  "$HOME/.local/share/$PREFIX/lib/bash"
  "$HOME/.local/share/$PREFIX/shell/hooks/envs"
  "$HOME/.config/$PREFIX"
  "$HOME/.claude/commands"
)

for DIR in "${DIRECTORIES[@]}"; do
  if [[ -z "$REVERT" ]]; then
    info "Creating directory at '$DIR'..."
    mkdir -p "$DIR"
  else
    warn "Removing directory at '$DIR'..."
    rm -rf "$DIR"
  fi
done
