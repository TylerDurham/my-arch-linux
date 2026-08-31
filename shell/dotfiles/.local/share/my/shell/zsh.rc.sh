# #############################################################################
# ___  ____ _  _    ____ ____ 
#   /  [__  |__|    |__/ |    
#  /__ ___] |  |   |  \ |___ 
#
# NOTE: Custom shell completions are located in ~/.local/share/zinit/completions
#
# ##############################################################################


# ==============================================================================
# LOAD ENVs
# ==============================================================================

typeset -U path

source "$HOME/.local/share/my/shell/zsh.envs.sh"

# Only run the rest in interactive shell!
[[ $- == *i* ]] || {
  echo "NON-INTERACTIVE SHELL"; return 0
}

# ==============================================================================
#  LOAD LIBS
# ==============================================================================

source "$MY_INSTALL_DIR/shell/zsh.plugins.sh"
source "$MY_INSTALL_DIR/shell/zsh.aliases.sh"

# ==============================================================================
# ZSH SPECIFIC ALIASES and SETTINGS
# ==============================================================================

# Reload ZSH without reloading the shell.
zreload() {
  source ~/.zshrc
}

# TMUX utility from ThePrimeagen
bindkey -s ^f "tmux-sessionizer\n"

# =======================================================================================
# SHELL INTEGRATIONS (Keep at bottom)
# =======================================================================================

# NGROK
if command -v ngrok &>/dev/null; then
  eval "$(ngrok completion)"
fi

# MISE
if command -v mise >& /dev/null; then
  eval "$(mise activate zsh)"
fi

# FZF
if command -v fzf >& /dev/null; then 
  eval "$(fzf --zsh)"
fi

# ZOXIDE
if command -v zoxide >& /dev/null; then 
  eval "$(zoxide init --cmd cd zsh)"
fi

# STARSHIP
if command -v starship >& /dev/null; then 
  eval "$(starship init zsh)"
fi



