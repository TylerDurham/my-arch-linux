
# Libraries
dependancies=(logger err_codes text)
if ! . "$MY_LIB_DIR/bash/require.sh" ${dependancies[@]}; then
  echo "FATAL: Could not load dependancies '${dependancies[@]}' from '$MY_LIB_DIR'!" >&2; exit 2
fi

MODULES=()
OPTIONS=0
declare -g -r OPT_SELECT=1
declare -g -r OPT_EXTRA=2
declare -g -r OPT_INSTALL=4
declare -g -r OPT_UNINSTALL=8
declare -g -r OPT_VERBOSE=16
declare -g -r OPT_PACKAGE=32
declare -g -r OPT_DRYRUN=64

declare -ra INSTALLER_OPTIONS=(
    OPT_SELECT
    OPT_EXTRA
    OPT_INSTALL
    OPT_UNINSTALL
    OPT_VERBOSE
    OPT_PACKAGE
    OPT_DRYRUN
)

installer_started() {
  while [[ "$#" -gt 0 ]]; do 
    case "$1" in 
      -h|--help) ACTION="HELP"; shift; ;;
      -i|--install) OPTIONS=$(( OPTIONS | OPT_INSTALL )); shift; ;;
      -n|--dryrun) OPTIONS=$(( OPTIONS | OPT_DRYRUN )); shift; ;;
      -u|--uninstall) OPTIONS=$(( OPTIONS | OPT_UNINSTALL )); shift ;;
      -s|--select) OPTIONS=$(( OPTIONS | OPT_SELECT )); shift ;;
      -x|--extra) OPTIONS=$(( OPTIONS | OPT_EXTRA )); shift ;;
      -v|--verbose) OPTIONS=$(( OPTIONS | OPT_VERBOSE )); shift ;;
      *) break ;;
    esac
  done

  echo "${OPTIONS[@]}"
}

installer_completed() {
  (( LOG_LEVEL >= 8 )) && {
    echo 
    debug_badge "$(basename $0)"
    debug "OPTIONS: "
    echo "$(printf '%d = 0x%x = ' "$OPTIONS" "$OPTIONS")$(to_binary $OPTIONS)" | indent
    for opt in $(print_bitmask_names INSTALLER_OPTIONS "${OPTIONS[@]}"); do echo "$opt" | indent; done;
    debug "SEARCH_PATH: $SEARCH_PATH"
    debug "MODULES: "
    for module in "${MODULES[@]}"; do echo "$module" | indent; done;
    debug_badge "ENV"
    debug "LOG_LEVEL: $LOG_LEVEL"
    debug "MY_LIB_DIR: $MY_LIB_DIR"
    debug "REPO_ROOT: $REPO_ROOT"
  }
}


# Reads the install/uninstall bit from the bitmask
get_action() {
  local options=$1

  if (( (options & OPT_INSTALL) == OPT_INSTALL)); then
    echo -n "install"
  elif (( (options & OPT_UNINSTALL) == OPT_UNINSTALL)); then
    echo -n "uninstall"
  else
    echo -n ""
  fi
}


process_package() {
  local root="$(pwd)"
  local options="$1"
  local package="$2"
  local action="$(get_action $options)"
  local search_path="$root/$package/install.d/*.sh"
  local modules=()

  [[ "$package" == "" ]] && fatal 1 "no package specified."
  [[ -d "$root" ]] || fatal 2 "Package directory '$search_path' not found!"
  [[ "$action" == "" ]] && {
    fatal 1 "no action specified."
  }

  package_badge $action "${action}ing package '$package'..."

  # Gather modules
  if (( (OPTIONS & OPT_SELECT) == OPT_SELECT )); then
    mapfile -t modules < <(sys-select-items -m "$search_path")
  else
    mapfile -t modules < <(sys-list-items "$search_path")
  fi

  process_modules $options "${modules[@]}"
}

process_packages() {
  local options=$1
  local packages="$2"

  for package in "${packages[@]}"; do 
    process_package $options "$package"
  done
}

process_module() {
  local options=$1
  local module_path="$2"
  local action=$(get_action $options)
  local status=0

  [[ "$action" == "" ]] && {
    fatal 1 "No action specified."
  }

  if [[ ! -f "$module_path" ]]; then
    warn "Module '$module_path' could not be found."
    return
  fi

  module_badge "$action" "$(basename $module_path)" | indent 2

  # Each module is sourced in a subshell so its globals (readonly CWD and
  # friends) and hook definitions cannot collide with the runner or leak into
  # the module processed next.
  (
    local hook

    source "$module_path"

    # Call 'on_init' hook if it exists
    if declare -F "on_init" >/dev/null; then
      on_init
    fi

    # 'on_install' 'on_uninstall' hooks MUST exist
    hook="on_${action}"
    declare -F "$hook" >/dev/null \
      && "$hook" \
      || { error "Module '$module_path' does not define ${hook}()."; exit "$EX_NOINPUT"; }

    # Call 'on_completed' hook if it exists
    if declare -F "on_completed" >/dev/null; then
        on_completed
    fi

  ) || status=$?

  if [[ $status -ne 0 ]]; then
    fatal 2 "Module '$module_path' failed with exit code ${status}."
  fi
}

process_modules() {
  local options=$1
  local action=$(get_action $options)
  shift
  local modules=("$@")

  [[ "$action" == "" ]] && {
    fatal 1 "No action specified."
  }

  for module in "${modules[@]}"; do 
    process_module $options "$module"
  done
}

