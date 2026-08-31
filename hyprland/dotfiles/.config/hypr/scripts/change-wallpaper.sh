#!/usr/bin/env bash

# Load libs
source "$MY_LIB_DIR/bash/require.sh" logger

set -eoEu pipefail

# Collect stderr from the helpers here so diagnostics never pollute the
# captured wallpaper path (that mixing is what produced the bogus
# "Image 'magick:' does not exist" error) but are still available for
# the failure notification below.
ERR_LOG=$(mktemp)

on-exit() {
  local rc=$?
  if (( rc > 0 )); then
    notify-send -i dialog-warning "Error!" \
      "An error has occured while changing the wallpaper:\n$(cat "$ERR_LOG")"
  fi
  rm -f "$ERR_LOG"
}

trap on-exit EXIT

# Prompt for a wallpaper. Only stdout (the chosen path) is captured.
wallpaper=$(hypr-select-wallpaper -d "$HOME/.config/my/theme/backgrounds" 2>>"$ERR_LOG")

if [[ -z "$wallpaper" ]]; then
  warn "No wallpaper selected."
  exit
fi

hypr-set-wallpaper -i "$wallpaper" 2>>"$ERR_LOG"

thumbnail=$(sys-cache-thumbnail -i "$wallpaper" 2>>"$ERR_LOG")

notify-send -i "$thumbnail" "Success!" "Wallpaper changed to '$(basename "$wallpaper")'"
