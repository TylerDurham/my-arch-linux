#!/usr/bin/env bash
#
# gtk-theme.sh - install (or remove) the Graphite GTK theme
#
# Usage:
#   ./gtk-theme.sh              install the theme and select it via gsettings
#   ./gtk-theme.sh -f|--force   reinstall even if the theme is already present
#   ./gtk-theme.sh -r|--revert  uninstall the theme and reset gsettings
#   ./gtk-theme.sh -h|--help    show this help
#
# The theme is built from vinceliuice/Graphite-gtk-theme, whose install.sh
# writes the variants into ~/.local/share/themes and - because we pass
# --libadwaita - also links the GTK4 assets into ~/.config/gtk-4.0.

set -euo pipefail

readonly THEME_NAME="Graphite-Dark"
readonly THEME_REPO="https://github.com/vinceliuice/Graphite-gtk-theme.git"
readonly THEME_ARGS=(--theme all --libadwaita -n Graphite -c dark --tweaks rimless black normal)
readonly THEMES_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/themes"
readonly GTK4_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/gtk-4.0"

# nwg-look edits the same gsettings keys this script writes; it is the GUI
# escape hatch for tweaking the theme afterwards.
readonly DEPS=(git nwg-look)

# GTK4 files the upstream installer symlinks into place with --libadwaita.
readonly GTK4_LINKS=(gtk.css gtk-dark.css assets)

BUILD_DIR=""

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
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
        warn "gsettings not found (install glib2); theme installed but not selected."
        return
    fi

    info "Selecting ${THEME_NAME} via gsettings..."
    gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"      # GTK3 apps
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"   # GTK4/libadwaita apps
}

install_theme() {
    local force="$1"

    if [[ -d "${THEMES_DIR}/${THEME_NAME}" && $force -eq 0 ]]; then
        info "Theme '${THEME_NAME}' is already installed. Use --force to rebuild it."
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
    info "Done. Tweak further with nwg-look if you want."
}

# --- revert ------------------------------------------------------------------

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

revert_theme() {
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
        # Prime the sudo timestamp up front so the build does not stall on a
        # password prompt halfway through.
        sudo -v
        install_theme "$force"
    fi
}

main "$@"
