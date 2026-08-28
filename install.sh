#!/usr/bin/env bash
#
# install.sh - run the installer modules in install.d/
#
# Usage:
#   ./install.sh                      run every module in install.d/
#   ./install.sh -m|--module NAME...  run only the named modules (.sh optional)
#   ./install.sh -s|--select          pick modules interactively with fzf
#   ./install.sh -l|--list            list the available modules
#   ./install.sh -h|--help            show this help
#
# Each module in install.d/ is a standalone script setting up one piece of the
# system, so they can be run one at a time or as a full pass. Set DEBUG=1 in
# the environment for verbose logging.

set -euo pipefail

# EXIT CODES
EX_NOINPUT=66

# GLOBALS
MODULE_DIR="install.d"
MODULE_PATH="$(realpath $(dirname $0))/$MODULE_DIR"
MODULES=()

# --- logging ------------------------------------------------------------
if [[ -t 2 ]]; then
  LOG_RESET=$'\033[0m'
  LOG_BLUE=$'\033[34m'
  LOG_YELLOW=$'\033[33m'
  LOG_RED=$'\033[31m'
  LOG_PURPLE=$'\033[35m'
else
  LOG_RESET='' LOG_BLUE='' LOG_GRAY='' LOG_YELLOW='' LOG_RED=''
fi

_log() { printf '%s[%s]%s %s\n' "$2" "$1" "$LOG_RESET" "${*:3}" >&2; }

info()  { _log INFO  "$LOG_BLUE"   "$@"; }
debug() { [[ -n "${DEBUG:-}" ]] || return 0; _log DEBUG "$LOG_PURPLE" "$@"; }
warn()  { _log WARN  "$LOG_YELLOW" "$@"; }
error() { _log ERROR "$LOG_RED"    "$@"; }
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

install_module() {
  local module_path="$1"

  if [[ ! -f "$module_path" ]]; then
    warn "Module '$module_path' could not be found."
  else
    info "Installing module '$module_path'..."
  fi
}

install_modules() {
  local modules=("$@")

  for module in "${modules[@]}"; do 
    install_module "$module"
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
    *) break ;;
  esac
done

if [[ "${#MODULES[@]}" -gt 0 ]]; then
  info "${#MODULES[@]} modules passed as args."
  install_modules "${MODULES[@]}"
else
  info "No modules passed as args."
  shopt -s nullglob
  install_modules "$MODULE_PATH"/*.sh
  shopt -u nullglob
fi

