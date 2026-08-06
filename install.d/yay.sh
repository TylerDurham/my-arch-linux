#!/usr/bin/env bash
#
# yay.sh - install (or remove) the yay AUR helper
#
# Usage:
#   ./yay.sh              install yay and its build dependencies
#   ./yay.sh -r|--revert  uninstall yay
#   ./yay.sh -h|--help    show this help
#
# yay is built from source via makepkg, which refuses to run as root, so this
# script must be run as a normal user with sudo privileges.

set -euo pipefail

readonly AUR_URL="https://aur.archlinux.org/yay.git"
readonly DEPS=(base-devel git)

BUILD_DIR=""

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
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
        || die "Do not run this script as root; makepkg refuses to build as root."

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
        info "Build dependencies already present: ${DEPS[*]}"
        return
    fi

    info "Installing build dependencies: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
}

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

    info "Done: $(yay --version | head -n1)"
}

# --- revert ------------------------------------------------------------------

revert_yay() {
    if ! is_installed yay; then
        warn "yay is not installed; nothing to remove."
        return
    fi

    info "Removing yay and any dependencies it no longer needs..."
    sudo pacman -Rns --noconfirm yay

    info "yay removed. Build dependencies (${DEPS[*]}) were left in place."
}

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--revert) revert=1 ;;
            -h|--help)   usage; exit 0 ;;
            *)           error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment

    # Prime the sudo timestamp up front so the build does not stall on a
    # password prompt halfway through.
    sudo -v

    if [[ $revert -eq 1 ]]; then
        revert_yay
    else
        install_yay
    fi
}

main "$@"
