# Current directory (relative to this file)
readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging helper.
log() {
  debug "$FUNCNAME $*" 2>&1 | indent 4
}

# Called by source script. Initializes the module.
on_init() {
  log "inside $FUNCNAME module ${0}" 
}

# Called by source script. Installs the module.
on_install() {
  log "inside $FUNCNAME module ${0}" 
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "inside $FUNCNAME module ${0}"
  log $CWD
}
