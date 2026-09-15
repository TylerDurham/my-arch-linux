# ==========================================================================================
# UTILITY
# ==========================================================================================

alias cls=clear
alias c='clear'
alias cat='bat'

# ==========================================================================================
# LSD
# ==========================================================================================

alias ls='lsd --icon auto'
alias l='lsd --icon auto -lh'
alias ll='lsd --icon auto -lah'
alias la='lsd --icon auto -A'
alias lr='lsd --icon auto -R'
alias lg='lsd --icon auto -l --group-directories-first'

# ==========================================================================================
# CROSS-PLATFORM PACKAGE MANAGEMENT HELPER FUNCTIONS
# ==========================================================================================

# Install one or more packages.
pmi() {
  if [ -f "/etc/arch-release" ]; then
    pacman -S --noconfirm --needed --quiet "$@"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew install --quiet "$@"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}

# Query for a single package.
pmq() {
  if [ -f "/etc/arch-release" ]; then
    pacman -Ss "$1"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew list "$1"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}

# Remove one or more packages.
pmr() {
  if [ -f "/etc/arch-release" ]; then
    pacman -R "$@"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew remove --quiet "$@"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}
