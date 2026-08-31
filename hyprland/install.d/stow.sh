#!/usr/bin/env bash

source "$(git rev-parse --show-toplevel)/install.d/envs.sh"

init "$@"

SOURCE="$PROJECT_ROOT_DIR/dotfiles"
TARGET="$HOME/"

if [[ -z "$REVERT" ]]; then
  info "Stowing '$SOURCE' to '$TARGET'..."
  stow  --dir $SOURCE -S . -t $TARGET

else
  info "Unstowing '$SOURCE' from '$TARGET'..."
  stow --dir $SOURCE -D . -t $TARGET
fi
