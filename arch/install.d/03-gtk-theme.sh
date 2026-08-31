# gtk-theme.sh - install (or remove) the Graphite GTK theme
#
# The theme is built from vinceliuice/Graphite-gtk-theme, whose install.sh
# writes the variants into ~/.local/share/themes and - because we pass
# --libadwaita - also links the GTK4 assets into ~/.config/gtk-4.0.
#
# Set FORCE=1 in the environment to rebuild a theme that is already present.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"           # Current directory (relative to this file)
readonly THEME_NAME="Graphite-Dark"                                     # Theme variant we install and select
readonly THEME_REPO="https://github.com/vinceliuice/Graphite-gtk-theme.git" # Upstream theme repository
readonly THEMES_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/themes"     # Where the variants are written
readonly GTK4_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/gtk-4.0"         # Where --libadwaita links GTK4 assets
FORCE="${FORCE:-0}"                                                     # Rebuild even if already installed
BUILD_DIR=""                                                            # Temporary clone dir, set at build time

# Arguments handed to the upstream install.sh.
readonly THEME_ARGS=(--theme all --libadwaita -n Graphite -c dark --tweaks rimless black normal)

# nwg-look edits the same gsettings keys this module writes; it is the GUI
# escape hatch for tweaking the theme afterwards.
readonly DEPS=(git nwg-look)

# GTK4 files the upstream installer symlinks into place with --libadwaita.
readonly GTK4_LINKS=(gtk.css gtk-dark.css assets)

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
  # Prime the sudo timestamp up front so the build does not stall on a
  # password prompt halfway through. Only the install path needs root; the
  # uninstall path stays inside $HOME.
  sudo -v

  log "$FUNCNAME: Installing ${THEME_NAME} into ${THEMES_DIR}"
  install_theme
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing Graphite themes from ${THEMES_DIR}"
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
        warn "gsettings not found (install glib2); theme installed but not selected."
        return
    fi

    info "Selecting ${THEME_NAME} via gsettings..."
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"      # GTK3 apps
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"   # GTK4/libadwaita apps
}

# Clone the theme and run its installer, then select the variant.
install_theme() {
    if [[ -d "${THEMES_DIR}/${THEME_NAME}" && $FORCE -eq 0 ]]; then
        info "Theme '${THEME_NAME}' is already installed. Set FORCE=1 to rebuild it."
        apply_gsettings
        return
    fi

    install_dependencies

    BUILD_DIR="$(mktemp -d)"
    trap cleanup EXIT

    info "Cloning ${THEME_REPO}..."
    git clone --depth 1 "$THEME_REPO" "$BUILD_DIR"

    info "Building the theme variants (this takes a minute)..."
    "$BUILD_DIR/install.sh" "${THEME_ARGS[@]}"

    [[ -d "${THEMES_DIR}/${THEME_NAME}" ]] \
        || die "Installer finished but ${THEMES_DIR}/${THEME_NAME} is missing; something went wrong."

    apply_gsettings
    log "Done. Tweak further with nwg-look if you want."
}

# Drop the GTK4 symlinks, but only the ones still pointing at a Graphite theme:
# a link the user re-pointed somewhere else is not ours to delete.
remove_gtk4_links() {
    local name target

    for name in "${GTK4_LINKS[@]}"; do
        target="${GTK4_DIR}/${name}"
        [[ -L "$target" ]] || continue

        case "$(readlink -f "$target")" in
            "${THEMES_DIR}"/Graphite*) rm -f "$target"; printf '   removed %s\n' "$target" ;;
        esac
    done
}

reset_gsettings() {
    command -v gsettings >/dev/null 2>&1 || return

    case "$(gsettings get org.gnome.desktop.interface gtk-theme)" in
        *Graphite*)
            info "Resetting the gtk-theme gsetting..."
            gsettings reset org.gnome.desktop.interface gtk-theme
            ;;
    esac
}

# Remove every Graphite variant, its GTK4 links, and the gsettings selection.
uninstall_theme() {
    local dirs=()
    local dir

    shopt -s nullglob
    dirs=("${THEMES_DIR}"/Graphite*)
    shopt -u nullglob

    if [[ ${#dirs[@]} -eq 0 ]]; then
        warn "No Graphite themes found in ${THEMES_DIR}; nothing to remove."
    else
        info "Removing ${#dirs[@]} theme variant(s) from ${THEMES_DIR}"
        for dir in "${dirs[@]}"; do
            rm -rf "$dir"
            printf '   removed %s\n' "${dir##*/}"
        done
    fi

    remove_gtk4_links
    reset_gsettings

    # color-scheme is a general dark-mode preference, not ours to undo.
    info "Left color-scheme set to $(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo unknown)."
}
