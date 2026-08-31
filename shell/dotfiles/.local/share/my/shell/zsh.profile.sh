source ~/.local/share/my/shell/zsh.envs.sh

# =======================================================================================
# HOOKs: Run boot hooks set by other repos
# =======================================================================================
for hook in $HOME/.local/share/my/shell/hooks/boot/*.sh; do 
  # echo "Running hook '$(basename $hook)'..."
  source "$hook"
done
