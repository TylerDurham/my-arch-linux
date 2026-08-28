#!/usr/bin/env bash
#
# packages.sh - install (or remove) the repo packages listed in packages.txt
#
# Usage:
#   ./packages.sh                  install every package in the list
#   ./packages.sh -y|--no-confirm  install without pacman's confirmation prompt
#   ./packages.sh -r|--revert      uninstall every package in the list
#   ./packages.sh -h|--help        show this help
#
# These come from the official repositories, so pacman installs them directly
# and no PKGBUILD review is involved. By default pacman prints the transaction
# and asks before committing to it; use --no-confirm for unattended re-runs of
# a list you have already vetted.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PACKAGE_LIST="${PACKAGE_LIST:-${SCRIPT_DIR}/packages.txt}"

PACKAGES=()

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

# --- checks ------------------------------------------------------------------

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

# --- install -----------------------------------------------------------------

install_packages() {
    local no_confirm="$1"
    local missing=()
    local pkg

    for pkg in "${PACKAGES[@]}"; do
        is_installed "$pkg" || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "All packages already installed: ${PACKAGES[*]}"
        return
    fi

    info "Installing from the repo: ${missing[*]}"

    if [[ $no_confirm -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        sudo pacman -S --needed "${missing[@]}"
    fi

    info "Done."
}

# --- revert ------------------------------------------------------------------

revert_packages() {
    local installed=()
    local pkg

    for pkg in "${PACKAGES[@]}"; do
        is_installed "$pkg" && installed+=("$pkg")
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "None of the listed AUR packages are installed; nothing to remove."
        return
    fi

    info "Removing: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"

    info "Removed ${#installed[@]} package(s)."
}

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0
    local no_confirm=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--revert)     revert=1 ;;
            -y|--no-confirm) no_confirm=1 ;;
            -h|--help)       usage; exit 0 ;;
            *)               error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment
    read_package_list

    # Prime the sudo timestamp up front so builds do not stall on a prompt.
    sudo -v

    if [[ $revert -eq 1 ]]; then
        revert_packages
    else
        install_packages "$no_confirm"
    fi
}

main "$@"
