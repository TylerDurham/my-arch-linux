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
pi() {
  if [ -f "/etc/arch-release" ]; then
    yay -S --noconfirm --needed --quiet "$@"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew install --quiet "$@"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}

# Query for a single package.
pq() {
  if [ -f "/etc/arch-release" ]; then
    yay -Ss "$1"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew list "$1"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}

# Remove one or more packages.
pr() {
  if [ -f "/etc/arch-release" ]; then
    yay -R "$@"
  elif [ "$(uname -s)" == "Darwin" ]; then
    brew remove --quiet "$@"
  else
    echo "Not implemented (yet) for $(uname -r)"
    exit 1
  fi
}
