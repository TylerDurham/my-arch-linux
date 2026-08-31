#!/usr/bin/env bash

set -euo pipefail

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

# --- options ------------------------------------------------------------
usage() {
  cat <<EOF
Usage: ${0##*/} [-h] [-v] [-n] [-f FILE] [-o DIR] [args...]

Options:
  -h          Show this help message and exit
  -v          Verbose output
  -n          Dry run; show what would happen without doing it
  -f FILE     Input file
  -o DIR      Output directory (default: .)
EOF
}

VERBOSE=0
DRY_RUN=0
FILE=""
OUTDIR="."

while getopts ":hvnf:o:" opt; do
  case "$opt" in
    h)  usage; exit 0 ;;
    v)  VERBOSE=1 ;;
    n)  DRY_RUN=1 ;;
    f)  FILE="$OPTARG" ;;
    o)  OUTDIR="$OPTARG" ;;
    :)  printf 'Error: -%s requires an argument\n' "$OPTARG" >&2; usage >&2; exit 2 ;;
    \?) printf 'Error: unknown option -%s\n' "$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
# -------------------------------------------------------------------------

info "FILE: $FILE"
info "OUTDIR: $OUTDIR"
info "VERBOSE: $VERBOSE"
info "DRY RUN: $DRY_RUN"
debug "DEBUG: Hello"


