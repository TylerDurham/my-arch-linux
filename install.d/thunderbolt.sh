# thunderbolt.sh - install boltd, the Thunderbolt device manager
#
# Thunderbolt devices are not trusted until they are authorized, so a freshly
# plugged dock or eGPU stays dark until boltd is running to enroll it. Enabling
# the service is what makes the *current* session able to authorize devices,
# rather than waiting for the next boot.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly PACKAGE="bolt"                                      # Package providing boltd and boltctl
readonly SERVICE="bolt.service"                              # Thunderbolt device manager service
NO_CONFIRM="${NO_CONFIRM:-0}"                                # Skip pacman's confirmation prompt

# Logging helper.
log() {
  debug "$*" 2>&1 | indent 4
}

# -------------------------------------------------------------------------------------------------
# HOOKS
# -------------------------------------------------------------------------------------------------

# Called by source script. Initializes the module.
on_init() {
  log "$FUNCNAME: Checking environment..."
  check_environment
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing ${PACKAGE}..."
  install_bolt

  log "$FUNCNAME: Enabling ${SERVICE}..."
  enable_service

  log "$FUNCNAME: Listing Thunderbolt devices..."
  list_devices
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Disabling ${SERVICE}..."
  disable_service

  log "$FUNCNAME: Removing ${PACKAGE}..."
  uninstall_bolt
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check that pacman is available and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it calls sudo where needed."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Install the bolt package
install_bolt() {
    if is_installed "$PACKAGE"; then
        info "${PACKAGE} already installed."
        return
    fi

    info "Installing ${PACKAGE} from the repo."

    if [[ $NO_CONFIRM -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm "$PACKAGE"
    else
        sudo pacman -S --needed "$PACKAGE"
    fi
}

# Enable boltd now and on boot, so the running session can authorize devices.
enable_service() {
    sudo systemctl enable --now "$SERVICE"
}

# Show the Thunderbolt devices boltd can see, as a post-install sanity check.
list_devices() {
    if ! command -v boltctl >/dev/null 2>&1; then
        warn "boltctl not found; skipping device list."
        return
    fi

    boltctl list
}

# Stop boltd and take it off the boot path.
disable_service() {
    if ! systemctl list-unit-files "$SERVICE" >/dev/null 2>&1; then
        warn "${SERVICE} not present; nothing to disable."
        return
    fi

    sudo systemctl disable --now "$SERVICE"
}

# Remove the bolt package
uninstall_bolt() {
    if ! is_installed "$PACKAGE"; then
        warn "${PACKAGE} is not installed; nothing to remove."
        return
    fi

    info "Removing ${PACKAGE}."
    sudo pacman -Rns --noconfirm "$PACKAGE"

    log "Removed ${PACKAGE}."
}
