#!/usr/bin/env bash
#
# install.sh - run the installer modules in install.d/
#
# Usage:
#   ./install.sh                      run every module in install.d/
#   ./install.sh -m|--module NAME...  run only the named modules (.sh optional)
#   ./install.sh -s|--select          pick modules interactively with fzf
#   ./install.sh -l|--list            list the available modules
#   ./install.sh -u|--uninstall       uninstall module(s)
#   ./install.sh -h|--help            show this help
#
# Each module in install.d/ is a standalone script setting up one piece of the
# system, so they can be run one at a time or as a full pass. Set DEBUG=1 in
# the environment for verbose logging.

set -euo pipefail

# EXIT CODES
readonly EX_NOINPUT=66

# GLOBALS
readonly MODULE_DIR="install.d"
readonly MODULE_PATH="$(realpath $(dirname $0))/$MODULE_DIR"
MODULES=()
UNINSTALL=0

# --- logging ------------------------------------------------------------
if [[ -t 2 ]]; then
  LOG_RESET=$'\033[0m'
  LOG_BLUE=$'\033[34m'
  LOG_GREEN=$'\033[32m'
  LOG_PURPLE=$'\033[35m'
  LOG_RED=$'\033[31m'
  LOG_YELLOW=$'\033[33m'
else
  LOG_RESET='' LOG_BLUE='' LOG_GREEN='' LOG_PURPLE='' LOG_RED='' LOG_YELLOW=''
fi

_log() { printf '%s%s%s %s\n' "$2" "$1" "$LOG_RESET" "${*:3}" >&2; }

debug() { [[ -n "${DEBUG:-}" ]] || return 0; _log [DEBUG] "$LOG_PURPLE" "$@"; }
error() { _log [ERROR] "$LOG_RED"    "$@"; }
die()   { echo ""; _log [FATAL] "$LOG_RED" "$@"; exit 1; }
info()  { _log [INFO]  "$LOG_BLUE"   "$@"; }
module() { _log "  󰕳" "$LOG_PURPLE" "$@"; }
success() { _log  "$LOG_GREEN" "$@"; }
warn()  { _log [WARN]  "$LOG_YELLOW" "$@"; }
indent() { sed "s/^/$(printf '%*s' "${1:-4}" '')/" >&2; }
# -------------------------------------------------------------------------

usage() {
  sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

list_modules() {
  local pretty=${1:-0}

  if [[ $pretty == 1 ]]; then
    info "The following modules are available for install:"
  fi
  
  for module in $MODULE_PATH/*.sh; do 
    if [[ $pretty == 1 ]]; then
      echo "$(basename $module)"
    else
      printf '%s\n' "$module"
    fi
  done
}

process_module() {
  local module_path="$1"
  local action="install"
  local status=0

  if [[ $UNINSTALL == 1 ]]; then
    action="uninstall"
  fi

  if [[ ! -f "$module_path" ]]; then
    warn "Module '$module_path' could not be found."
    return
  fi

  module "${action^}ing module '$module_path'..."

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
    die "Module '$module_path' failed with exit code ${status}."
  fi
}

process_modules() {
  local modules=("$@")

  for module in "${modules[@]}"; do 
    process_module "$module"
  done
}

while [[ "$#" -gt 0 ]]; do 
  case "$1" in 
    -h|--help) usage; exit 0 ;;
    -l|--list) list_modules 1; exit ;;
    -s|--select) 
      mapfile -t MODULES < <(list_modules | fzf -m --prompt "Select multiple modules by hitting <TAB>:"); 
      break ;;
    -m|--module) 
      shift
        while [[ $# -gt 0 && "$1" != -* ]]; do
            # [[ "$1" == *.sh ]] || 1+=".sh"
            MODULES+=("$MODULE_PATH/${1%.sh}.sh")
            shift
        done
      ;;
    -u|--uninstall) UNINSTALL=1; shift ;;
    *) break ;;
  esac
done

if [[ "${#MODULES[@]}" -gt 0 ]]; then
  info "${#MODULES[@]} modules passed as args. Processing ${#MODULES[@]} modules..."
  process_modules "${MODULES[@]}"
else
  info "No modules passed as args. Processing all modules..."
  mapfile -t MODULES < <(list_modules 0)
  process_modules "${MODULES[@]}"
fi

success "Done!"
