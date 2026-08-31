# =======================================================================================
# ZINIT (Load this FIRST, before other integrations)
# =======================================================================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# =======================================================================================
# COMPLETIONS (Optimized - only rebuild once a day)
# =======================================================================================
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(qN.mh+24) ]]; then
  compinit -C
else
  compinit 
fi

# =======================================================================================
# PLUGINS (Load asynchronously with 'wait')
# =======================================================================================
# Syntax highlighting - load after everything else
zinit wait lucid light-mode for \
  atinit"zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
    Aloxaf/fzf-tab

# Completions - load immediately but turbo mode
zinit light-mode for \
    zsh-users/zsh-completions

# OMZ snippets - also async

zle_highlight+=(paste:none)

# fpath+=~/.zfunc; autoload -Uz compinit; compinit
#
#
zstyle ':completion:*' menu select

