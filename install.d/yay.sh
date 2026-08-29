# yay.sh - install (or remove) the yay AUR helper
#
# yay is built from source via makepkg, which refuses to run as root, so this
# module must be run as a normal user with sudo privileges.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly AUR_URL="https://aur.archlinux.org/yay.git"         # yay's AUR git repository
readonly DEPS=(base-devel git)                               # Packages needed to build yay
BUILD_DIR=""                                                 # Temporary clone/build dir, set at build time

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

  # Prime the sudo timestamp up front so the build does not stall on a
  # password prompt halfway through.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing yay..."
  install_yay
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing yay..."
  uninstall_yay
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for pacman and sudo, and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; makepkg refuses to build as root."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install packages."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Drop the temporary build directory, however we leave the module.
cleanup() {
    if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}

install_dependencies() {
    local missing=()
    local dep

    for dep in "${DEPS[@]}"; do
        is_installed "$dep" || missing+=("$dep")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Build dependencies already present: ${DEPS[*]}"
        return
    fi

    info "Installing build dependencies: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
}

# Clone yay from the AUR and build it with makepkg.
install_yay() {
    if command -v yay >/dev/null 2>&1; then
        info "yay is already installed ($(yay --version | head -n1)). Nothing to do."
        return
    fi

    install_dependencies

    BUILD_DIR="$(mktemp -d)"
    trap cleanup EXIT

    info "Cloning yay from the AUR..."
    git clone --depth 1 "$AUR_URL" "$BUILD_DIR/yay"

    info "Building and installing yay (this compiles Go sources; it may take a while)..."
    (cd "$BUILD_DIR/yay" && makepkg -si --noconfirm)

    command -v yay >/dev/null 2>&1 \
        || die "Build finished but yay is not on PATH; something went wrong."

    log "Installed $(yay --version | head -n1)"
}

# Remove yay, leaving the build dependencies in place.
uninstall_yay() {
    if ! is_installed yay; then
        warn "yay is not installed; nothing to remove."
        return
    fi

    info "Removing yay and any dependencies it no longer needs..."
    sudo pacman -Rns --noconfirm yay

    info "yay removed. Build dependencies (${DEPS[*]}) were left in place."
}
