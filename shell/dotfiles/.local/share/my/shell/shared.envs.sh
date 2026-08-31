# #########################################################################
# ____ _  _ _  _ ____ 
# |___ |\ | |  | [__  
# |___ | \|  \/  ___] 
#
# #########################################################################

if [[ "$OSTYPE" == "darwin"* ]]; then
  # Put Homebrew bin first so env bash finds modern version
  export PATH="$(brew --prefix)/bin:$PATH"
fi 

export MY_INSTALL_DIR="$HOME/.local/share/my" #$(dtdconfig get env.INSTALL_DIR | envsubst)" 
export MY_BIN_DIR="$HOME/.local/share/my/bin" #$(dtdconfig get env.BIN_DIR | envsubst)"
export MY_LIB_DIR="$MY_INSTALL_DIR/lib" #$(dtdconfig get env.LIB_DIR | envsubst)"
export MY_CONFIG_DIR="$HOME/.config/my" #$(dtdconfig get env.CONFIG_DIR | envsubst)"
export MY_LOG_DIR="/tmp" #$(dtdconfig get env.LOG_DIR | envsubst)"
export MY_APP_DIR="$HOME/.local/share/applications" #$(dtdconfig get env.APP_DIR | envsubst)"

mkdir -p "$MY_LOG_DIR" # Ensure log directory exists

# NOTE: New "my" prefix
export MY_BASH_LIB_DIR="$MY_LIB_DIR/bash"
export MY_BASH_LIB_DIR="$MY_LIB_DIR/bash"
export MY_BIN_DIR="$MY_BIN_DIR"
export MY_CONFIG_DIR="$MY_CONFIG_DIR"
export MY_LIB_DIR="$MY_LIB_DIR"
export MY_LOG_DIR="$MY_LOG_DIR"
export MY_WALLPAPER_DIR="$MY_WALLPAPER_DIR"
export PATH="$MY_BIN_DIR:$HOME/go/bin:/usr/local/go/bin:$HOME/.local/bin:$PATH"

if command -v go &>/dev/null; then
  export PATH=$PATH:$(go env GOPATH)/bin
fi

# Programs
export EDITOR=nvim

# NOTE: Homelab APIs
export OLLAMA_HOST="https://ollama.snork.co"

# 1Password socket exits - configure ssh-agent
if [[ -S ~/.1password/agent.sock ]]; then
  export SSH_AUTH_SOCK=~/.1password/agent.sock
fi

# # =======================================================================================
# # LOGGING
# # =======================================================================================

if [[ ! -n "${MY_ENVS_LOADED}" ]]; then
  declare -rx LOG_LEVEL_FATAL=0
  declare -rx LOG_LEVEL_ERROR=1
  declare -rx LOG_LEVEL_WARN=2
  declare -rx LOG_LEVEL_INFO=4
  declare -rx LOG_LEVEL_DEBUG=8
  declare -x LOG_TO_FILE=0
  declare -x LOG_FILE=
fi

export LOG_LEVEL=$LOG_LEVEL_INFO

# LOAD LAST
declare -rx MY_ENVS_LOADED=1 &> /dev/null

# Load Ollama envs if they are present
[ -f "$HOME/ollama.env.sh" ] && source "$HOME/ollama.env.sh"

# KVM/qemu
export LIBGUESTFS_BACKEND=direct
export LIBVIRT_DEFAULT_URI="qemu:///system"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# =======================================================================================
# HOOKs: Run ENV hooks set by other repos
# =======================================================================================
for hook in $HOME/.local/share/my/shell/hooks/envs/*.sh; do 
  # echo "Running hook '$(basename $hook)'..."
  source "$hook"
done
