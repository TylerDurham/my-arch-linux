#!/usr/bin/env bash
# USAGE: usage.sh
# Do your thing

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

# --- usage ---------------------------------------------------------------
# Prints this script's header comment block: every comment line after the
# shebang, stopping at the first line that isn't a comment. Keep the block
# directly under the shebang, e.g.
#
#   #!/usr/bin/env bash
#   # myscript - do the thing
#   #
#   # Usage: myscript [-v] FILE
#   set -euo pipefail        <- block ends here
usage() {
  awk '
    NR == 1 && /^#!/ { next }                                  # skip the shebang
    /^#/             { sub(/^#[[:space:]]?/, ""); print; next } # strip "# " and print
                     { exit }                                  # first non-comment line ends it
  ' "${BASH_SOURCE[0]:-$0}"
}
# -------------------------------------------------------------------------

# Fail unless the option currently being parsed is followed by a value
need_arg() { (( $# >= 2 )) || { printf 'Error: %s requires an argument\n' "$1" >&2; exit 2; }; }

VERBOSE=0
DRY_RUN=0
FILE=""
OUTDIR="."
ARGS=()

while (( $# )); do
  case "$1" in
    -h|--help)     usage; exit 0 ;;
    -v|--verbose)  VERBOSE=1 ;;
    -n|--dry-run)  DRY_RUN=1 ;;
    -f|--file)     need_arg "$@"; FILE="$2"; shift ;;
    --file=*)      FILE="${1#*=}" ;;
    -o|--output)   need_arg "$@"; OUTDIR="$2"; shift ;;
    --output=*)    OUTDIR="${1#*=}" ;;
    --)            shift; ARGS+=("$@"); break ;;
    -[!-]?*)       # bundled shorts: -vn -> -v -n, -fFILE -> -f FILE
                   cluster="${1#-}"; shift
                   split=()
                   while [[ -n "$cluster" ]]; do
                     flag="${cluster:0:1}"; cluster="${cluster:1}"
                     split+=("-$flag")
                     # flags that take a value swallow the rest of the cluster
                     case "$flag" in
                       f|o) if [[ -n "$cluster" ]]; then split+=("$cluster"); cluster=""; fi ;;
                     esac
                   done
                   set -- "${split[@]}" "$@"
                   continue
                   ;;
    -*)            printf 'Error: unknown option %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *)             ARGS+=("$1") ;;
  esac
  shift
done
set -- "${ARGS[@]}"
# -------------------------------------------------------------------------

info "DRY RUN: $DRY_RUN"
