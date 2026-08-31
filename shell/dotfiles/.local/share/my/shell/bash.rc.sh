# ==============================================================================
# LOAD ENVs
# ==============================================================================

source "$HOME/.local/share/my/shell/shared.envs.sh"
source "$MY_INSTALL_DIR/shell/shared.aliases.sh"

# Only run the rest in interactive shell!
[[ $- == *i* ]] || return 0

# BIGGER HISTORY, DEDUP, USEFUL TIMESTAMPS
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups   # ignore dupes + leading-space commands
HISTTIMEFORMAT="%F %T  "
HISTIGNORE="ls:ll:cd:cd -:pwd:exit:clear:history"

# APPEND INSTEAD OF OVERWRITE (flush each prompt, but keep this session's
# recall order intact -- 'history -c; history -r' would reshuffle it)
shopt -s histappend
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}"

# SHELL GLOBBING
shopt -s autocd            # type a dir name to cd into it
shopt -s cdspell           # fix minor cd typos
shopt -s dirspell          # fix typos during completion
shopt -s checkwinsize      # update LINES/COLUMNS after resize
shopt -s globstar          # enable ** for recursive globbing
shopt -s nocaseglob        # case-insensitive globbing
shopt -s no_empty_cmd_completion

# LOAD COMPLETIONS
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
fi

# READLINE (these are .inputrc directives -- they must go through 'bind',
# the 'set' builtin would just clobber the positional parameters)
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set mark-symlinked-directories on'
bind 'set visible-stats on'

# TMUX utility from ThePrimeagen
bind '"\C-f": "tmux-sessionizer\n"'

# =======================================================================================
# SHELL INTEGRATIONS (Keep at bottom)
# =======================================================================================

# STARSHIP
if command -v starship >& /dev/null; then
  eval "$(starship init bash)"
fi

# MISE
if command -v mise >& /dev/null; then
  if [[ -z "$MISE_SHELL" ]]; then
    eval "$(mise activate bash)"
  fi
fi

# FZF
if command -v fzf >& /dev/null; then
  eval "$(fzf --bash)"
fi
