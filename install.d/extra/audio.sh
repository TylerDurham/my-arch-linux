# audio.sh - install the audio pieces Arch does not pull in by default
#
# Arch installs PipeWire without rtkit, so PipeWire's data-loop threads never
# get realtime scheduling and audio breaks up under load. rtkit is what lets
# them run at RR priority. The restart is what makes the *running* session pick
# rtkit up, so playback does not stay broken until the next login.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly PKGS=(rtkit)                                        # Realtime scheduling broker for PipeWire
readonly SERVICES=(pipewire pipewire-pulse wireplumber)      # User units restarted to pick rtkit up
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
  log "$FUNCNAME: Installing ${PKGS[*]}..."
  install_packages

  log "$FUNCNAME: Restarting the PipeWire stack..."
  restart_services
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing ${PKGS[*]}..."
  uninstall_packages

  log "$FUNCNAME: Restarting the PipeWire stack..."
  restart_services
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check that pacman is available and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it restarts your own user units."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

install_packages() {
    local missing=()
    local pkg

    for pkg in "${PKGS[@]}"; do
        if ! is_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Packages already present: ${PKGS[*]}"
        return
    fi

    info "Installing: ${missing[*]}"

    if [[ $NO_CONFIRM -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        sudo pacman -S --needed "${missing[@]}"
    fi
}

uninstall_packages() {
    local installed=()
    local pkg

    for pkg in "${PKGS[@]}"; do
        if is_installed "$pkg"; then
            installed+=("$pkg")
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "None of ${PKGS[*]} are installed; nothing to remove."
        return
    fi

    info "Removing: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"
}

# Restart the stack so the *running* session picks the change up, rather than
# leaving playback broken until the next login.
restart_services() {
    if ! systemctl --user is-active "${SERVICES[0]}" >/dev/null 2>&1; then
        warn "${SERVICES[0]} is not running in this session; skipping the restart."
        return
    fi

    systemctl --user restart "${SERVICES[@]}"
}
