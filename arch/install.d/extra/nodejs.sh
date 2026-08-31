#!/usr/bin/env bash

source "$(git rev-parse --show-toplevel)/install.d/envs.sh"

init "$@"

# Node is installed through mise rather than a system package manager, so the
# version is the same everywhere and upgrades don't fight with apt/pacman/brew.
# `node = "latest"` is written to the global config (~/.config/mise/config.toml)
# as a fuzzy version, so re-running this script picks up newer releases.

if [[ "$(sys-get-os)" == "nixos" ]]; then
  warn "No need to install 'nodejs' on NixOs."
  exit 0
fi

# Resolve mise: an explicit override first, then the copy 'dev/mise.sh'
# installs (which may not be on PATH yet during a fresh setup run), then
# whatever is on PATH -- that last one covers a package-manager install
# such as /usr/bin/mise on Arch.
if [[ -n "$MISE_INSTALL_PATH" ]]; then
  MISE_BIN="$MISE_INSTALL_PATH"
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  MISE_BIN="$HOME/.local/bin/mise"
else
  MISE_BIN=$(command -v mise)
fi

if [[ ! -x "$MISE_BIN" ]]; then
  fatal "'mise' not found on PATH or at '$HOME/.local/bin/mise'. Run '$CWD/mise.sh' first."
fi

if [[ -z "$REVERT" ]]; then
  info "Installing 'node@latest' via mise..."
  "$MISE_BIN" use --global --yes node@latest

  ok "node $("$MISE_BIN" exec -- node --version), npm $("$MISE_BIN" exec -- npm --version)"
else
  warn "Removing 'node' from the global mise config..."
  "$MISE_BIN" use --global --remove node

  warn "Uninstalling all 'node' versions..."
  "$MISE_BIN" uninstall --all node
fi
