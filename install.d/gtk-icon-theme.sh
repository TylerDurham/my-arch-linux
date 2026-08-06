#!/usr/bin/env bash
#
# gtk-icon-theme.sh - install (or remove) the Tela-circle icon theme
#
# Usage:
#   ./icon-theme.sh              install the icons and select them via gsettings
#   ./icon-theme.sh -f|--force   reinstall even if the theme is already present
#   ./icon-theme.sh -r|--revert  uninstall the theme and reset gsettings
#   ./icon-theme.sh -h|--help    show this help
#
# The theme is built from vinceliuice/Tela-circle-icon-theme, whose install.sh
# writes the variants into ~/.local/share/icons and rebuilds the icon caches.

set -euo pipefail

readonly THEME_NAME="Tela-circle-dracula"
readonly THEME_REPO="https://github.com/vinceliuice/Tela-circle-icon-theme.git"
readonly THEME_ARGS=(-n Tela-circle-dracula -c)
readonly ICONS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/icons"

# nwg-look edits the same gsettings key this script writes; it is the GUI
# escape hatch for tweaking the theme afterwards.
readonly DEPS=(git nwg-look)

BUILD_DIR=""

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

cleanup() {
    if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}

# --- checks ------------------------------------------------------------------

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

# --- install -----------------------------------------------------------------

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

install_theme() {
    local force="$1"

    if [[ -d "${ICONS_DIR}/${THEME_NAME}" && $force -eq 0 ]]; then
        info "Icon theme '${THEME_NAME}' is already installed. Use --force to rebuild it."
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
    info "Done. Tweak further with nwg-look if you want."
}

# --- revert ------------------------------------------------------------------

reset_gsettings() {
    command -v gsettings >/dev/null 2>&1 || return

    case "$(gsettings get org.gnome.desktop.interface icon-theme)" in
        *"${THEME_NAME}"*)
            info "Resetting the icon-theme gsetting..."
            gsettings reset org.gnome.desktop.interface icon-theme
            ;;
    esac
}

revert_theme() {
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

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0
    local force=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--revert) revert=1 ;;
            -f|--force)  force=1 ;;
            -h|--help)   usage; exit 0 ;;
            *)           error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment

    if [[ $revert -eq 1 ]]; then
        revert_theme
    else
        # Prime the sudo timestamp up front so the install does not stall on a
        # password prompt halfway through.
        sudo -v
        install_theme "$force"
    fi
}

main "$@"
