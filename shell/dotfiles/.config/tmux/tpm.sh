#!/usr/bin/env bash

if [ ! -d "$HOME/.config/tmux/plugins" ]; then
  mkdir -p "$HOME/.config/tmux/plugins"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
else
  echo "tpm installed already."
fi
