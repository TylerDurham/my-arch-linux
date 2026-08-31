

declare -A recommended_cmds=(
 )

 declare -A required_cmds=(
   ["stow"]="stow"
   ["git"]="git"
   ["fzf"]="fzf"
)

echo
info_badge "Checking prerequisites..."

for cmd in ${!required_cmds[@]}; do 
  pkg="${required_cmds[$cmd]}"
  debug "Checking if $cmd ($pkg) is installed.." 
  if ! command -v "$cmd" &> /dev/null; then 
    fatal 2 "Required command '$cmd' not found! Please install '$pkg' and then continue."
  fi
done

for cmd in ${!recommended_cmds[@]}; do 
  pkg="${recommended_cmds[$cmd]}"
  debug "Checking if $cmd ($pkg) is installed.." 
  if ! command -v "$cmd" &> /dev/null; then 
    warn "Recommended command '$cmd' not found! You may wish to install '$pkg' at some point."
  fi
done

info_badge "Prerequisite check finished."
echo

