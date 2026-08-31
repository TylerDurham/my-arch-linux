
source "$MY_LIB_DIR/bash/logger.sh"

MODULES=()
OPTIONS=0
declare -g -r OPT_SELECT=1
declare -g -r OPT_EXTRA=2
declare -g -r OPT_INSTALL=4
declare -g -r OPT_UNINSTALL=8
declare -g -r OPT_VERBOSE=16

get_action() {
  local flags=$1
  if (( (flags & OPT_INSTALL) == OPT_INSTALL)); then
    echo -n "install"
  elif (( (flags & OPT_UNINSTALL) == OPT_UNINSTALL)); then
    echo -n "uninstall"
  else
    echo -n ""
  fi
}

to_binary() {
    local -i n=$1 width=${2:-8}
    local bits=""
    for (( i = width - 1; i >= 0; i-- )); do
        bits+=$(( (n >> i) & 1 ))
    done
    printf '%s\n' "$bits"
}

process_module() {
  local action="$1"
  local module_path="${*:2}"
  local status=0

  [[ "$action" == "" ]] && {
    fatal 1 "No action specified."
  }

  if [[ ! -f "$module_path" ]]; then
    warn "Module '$module_path' could not be found."
    return
  fi

  info_badge "${action^}ing module '$module_path'..." | indent 2

  # Each module is sourced in a subshell so its globals (readonly CWD and
  # friends) and hook definitions cannot collide with the runner or leak into
  # the module processed next.
  (
    local hook

    source "$module_path"

    for hook in on_init "on_${action}"; do
      declare -F "$hook" >/dev/null \
        || { error "Module '$module_path' does not define ${hook}()."; exit "$EX_NOINPUT"; }
    done

    on_init
    "on_${action}"
  ) || status=$?

  if [[ $status -ne 0 ]]; then
    fatal 2 "Module '$module_path' failed with exit code ${status}."
  fi
}

process_modules() {
  local action=$(get_action $1)
  shift
  local modules=("$@")

  # echo "$action"
  # echo "${modules[@]}"
  # exit

  [[ "$action" == "" ]] && {
    fatal 1 "No action specified."
  }

  info_badge "Count of modules to '$action': ${#modules[@]}"
  for module in "${modules[@]}"; do 
    process_module "$action" "$module"
  done
}

