# packages.sh - install (or remove) the repo packages listed in packages.txt
#
# These come from the official repositories, so pacman installs them directly
# and no PKGBUILD review is involved. By default pacman prints the transaction
# and asks before committing to it; set NO_CONFIRM=1 in the environment for
# unattended re-runs of a list you have already vetted.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly PACKAGE_LIST="${PACKAGE_LIST:-${CWD}/packages.txt}" # File listing the packages to install
NO_CONFIRM="${NO_CONFIRM:-0}"                                # Skip pacman's confirmation prompt

# Array to hold packages to be installed, read from $PACKAGE_LIST
PACKAGES=()

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

  log "$FUNCNAME: Reading package list..."
  read_package_list

  # Prime the sudo timestamp up front so pacman does not stall on a prompt.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing ${#PACKAGES[@]} package(s) from ${PACKAGE_LIST}"
  install_packages
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing ${#PACKAGES[@]} package(s) listed in ${PACKAGE_LIST}"
  uninstall_packages
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

# Read the package list, skipping blank lines and '#' comments.
read_package_list() {
    [[ -f "$PACKAGE_LIST" ]] \
        || die "Package list not found: ${PACKAGE_LIST}"

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"                  # strip trailing comments
        line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # trim trailing whitespace
        [[ -n "$line" ]] && PACKAGES+=("$line")
    done < "$PACKAGE_LIST"

    [[ ${#PACKAGES[@]} -gt 0 ]] \
        || die "No packages listed in ${PACKAGE_LIST}"
}

# Install the packages
install_packages() {
    local missing=()
    local pkg

    for pkg in "${PACKAGES[@]}"; do
        if ! is_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log "All packages already installed: ${PACKAGES[*]}"
        return
    fi

    log "Installing from the repo: ${missing[*]}"

    if [[ $NO_CONFIRM -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        sudo pacman -S --needed "${missing[@]}"
    fi

    log "Installed ${#missing[@]} package(s)."
}

# Uninstall the packages
uninstall_packages() {
    local installed=()
    local pkg

    for pkg in "${PACKAGES[@]}"; do
        if is_installed "$pkg"; then
            installed+=("$pkg")
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "None of the listed packages are installed; nothing to remove." 2>&1 | indent 4
        return
    fi

    log "Removing: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"

    log "Removed ${#installed[@]} package(s) from the system."
}
