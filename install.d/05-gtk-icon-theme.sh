# gtk-icon-theme.sh - install (or remove) the Tela-circle icon theme
#
# The theme is built from vinceliuice/Tela-circle-icon-theme, whose install.sh
# writes the variants into ~/.local/share/icons and rebuilds the icon caches.
#
# Set FORCE=1 in the environment to rebuild a theme that is already present.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"          # Current directory (relative to this file)
readonly THEME_NAME="Tela-circle-dracula"                             # Icon theme we install and select
readonly THEME_REPO="https://github.com/vinceliuice/Tela-circle-icon-theme.git" # Upstream theme repository
readonly THEME_ARGS=(-n Tela-circle-dracula -c)                       # Arguments for the upstream install.sh
readonly ICONS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/icons"     # Where the variants are written
FORCE="${FORCE:-0}"                                                   # Rebuild even if already installed
BUILD_DIR=""                                                          # Temporary clone dir, set at build time

# nwg-look edits the same gsettings key this module writes; it is the GUI
# escape hatch for tweaking the theme afterwards.
readonly DEPS=(git nwg-look)

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
  # Prime the sudo timestamp up front so the install does not stall on a
  # password prompt halfway through. Only the install path needs root; the
  # uninstall path stays inside $HOME.
  sudo -v

  log "$FUNCNAME: Installing ${THEME_NAME} into ${ICONS_DIR}"
  install_theme
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing ${THEME_NAME} from ${ICONS_DIR}"
  uninstall_theme
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for pacman and sudo, and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; the theme installs into your home directory."

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
        info "Dependencies already present: ${DEPS[*]}"
        return
    fi

    info "Installing dependencies: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
}

apply_gsettings() {
    if ! command -v gsettings >/dev/null 2>&1; then
        warn "gsettings not found (install glib2); icons installed but not selected."
        return
    fi

    info "Selecting ${THEME_NAME} via gsettings..."
    gsettings set org.gnome.desktop.interface icon-theme "$THEME_NAME"
}

# Clone the theme and run its installer, then select the variant.
install_theme() {
    if [[ -d "${ICONS_DIR}/${THEME_NAME}" && $FORCE -eq 0 ]]; then
        info "Icon theme '${THEME_NAME}' is already installed. Set FORCE=1 to rebuild it."
        apply_gsettings
        return
    fi

    install_dependencies

    BUILD_DIR="$(mktemp -d)"
    trap cleanup EXIT

    info "Cloning ${THEME_REPO}..."
    git clone --depth 1 "$THEME_REPO" "$BUILD_DIR"

    info "Installing the icon theme (this renders a lot of SVGs; give it a minute)..."
    "$BUILD_DIR/install.sh" "${THEME_ARGS[@]}"

    [[ -d "${ICONS_DIR}/${THEME_NAME}" ]] \
        || die "Installer finished but ${ICONS_DIR}/${THEME_NAME} is missing; something went wrong."

    apply_gsettings
    log "Done. Tweak further with nwg-look if you want."
}

reset_gsettings() {
    command -v gsettings >/dev/null 2>&1 || return

    case "$(gsettings get org.gnome.desktop.interface icon-theme)" in
        *"${THEME_NAME}"*)
            info "Resetting the icon-theme gsetting..."
            gsettings reset org.gnome.desktop.interface icon-theme
            ;;
    esac
}

# Remove every variant we installed and drop the gsettings selection.
uninstall_theme() {
    local dirs=()
    local dir

    # Only variants of the name we installed under - other Tela themes the user
    # put there by hand are not ours to delete.
    shopt -s nullglob
    dirs=("${ICONS_DIR}/${THEME_NAME}"*)
    shopt -u nullglob

    if [[ ${#dirs[@]} -eq 0 ]]; then
        warn "No ${THEME_NAME} icons found in ${ICONS_DIR}; nothing to remove."
    else
        info "Removing ${#dirs[@]} icon theme variant(s) from ${ICONS_DIR}"
        for dir in "${dirs[@]}"; do
            rm -rf "$dir"
            printf '   removed %s\n' "${dir##*/}"
        done
    fi

    reset_gsettings
}
