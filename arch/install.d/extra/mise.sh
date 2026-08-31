#!/usr/bin/env bash

source "$(git rev-parse --show-toplevel)/install.d/envs.sh"

init "$@"

# mise (https://mise.jdx.dev) is a polyglot tool-version manager. The upstream
# installer at https://mise.run drops a single static binary into
# ~/.local/bin and keeps everything else under the XDG dirs, so there is no
# package-manager dependency and nothing to stow.

if [[ "$(sys-get-os)" == "nixos" ]]; then
  warn "No need to install 'mise' on NixOs."
  exit 0
fi

MISE_BIN="${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}"
MISE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
MISE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mise"
MISE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mise"

if [[ -z "$REVERT" ]]; then
  if ! command -v curl &>/dev/null; then
    fatal "'curl' is required to install mise."
  fi

  if [[ -x "$MISE_BIN" ]]; then
    info "'mise' already installed at '$MISE_BIN'... upgrading..."
    "$MISE_BIN" self-update --yes
  else
    info "Installing 'mise' to '$MISE_BIN'..."
    curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_BIN" sh
  fi

  [[ -x "$MISE_BIN" ]] || fatal "'mise' install failed, '$MISE_BIN' not found."

  ok "$("$MISE_BIN" --version)"
else
  if [[ -e "$MISE_BIN" ]]; then
    warn "Removing '$MISE_BIN'..."
    rm -f "$MISE_BIN"
  fi

  # Installed tools, shims and caches. The user's config under
  # ~/.config/mise is left alone — mise never wrote it, we didn't either.
  for DIR in "$MISE_DATA_DIR" "$MISE_STATE_DIR" "$MISE_CACHE_DIR"; do
    if [[ -d "$DIR" ]]; then
      warn "Removing '$DIR'..."
      rm -rf "$DIR"
    fi
  done
fi
