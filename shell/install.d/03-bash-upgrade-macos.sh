#!/usr/bin/env bash

# macOS ships bash 3.2 at /bin/bash (last GPLv2 release) and never updates it.
# Scripts that use bash 4+ features (e.g. associative arrays, like
# sys-get-os-icon) silently break under it. Homebrew's bash sits at
# /opt/homebrew/bin (or /usr/local/bin on Intel), which is already ahead of
# /bin on PATH, so installing it is enough for `#!/usr/bin/env bash` scripts
# to pick up the modern version without changing anyone's login shell.

on_init() {
  log "$(basename $module) initializing..."

  # Modules are sourced in their own subshell, so exiting here skips the
  # install/uninstall hook without failing the run.
  if [[ "$(uname -s)" != "Darwin" ]]; then
    warn "Not on macOS, skipping bash upgrade..." 2>&1 | indent
    exit 0
  fi

  command -v brew &>/dev/null \
    || fatal 1 "Homebrew not found. Install it from https://brew.sh first."

  BREW_PREFIX="$(brew --prefix)"
  BREW_BASH="$BREW_PREFIX/bin/bash"
}

on_install() {
  if brew list bash &>/dev/null; then
    log "Upgrading Homebrew bash..."
    brew upgrade bash
  else
    log "Installing Homebrew bash..."
    brew install bash
  fi

  if ! grep -qx "$BREW_BASH" /etc/shells 2>/dev/null; then
    log "Registering '$BREW_BASH' in /etc/shells (requires sudo)..."
    echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null
  fi

  ok "$($BREW_BASH --version | head -1)" 2>&1 | indent
}

on_uninstall() {
  if brew list bash &>/dev/null; then
    warn_badge "Uninstalling Homebrew bash..." 2>&1 | indent
    brew uninstall bash
  fi

  if grep -qx "$BREW_BASH" /etc/shells 2>/dev/null; then
    warn_badge "Removing '$BREW_BASH' from /etc/shells (requires sudo)..." 2>&1 | indent
    sudo sed -i '' "\|^${BREW_BASH}\$|d" /etc/shells
  fi
}
