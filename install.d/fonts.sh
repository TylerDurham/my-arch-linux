#!/usr/bin/env bash
#
# fonts.sh - install (or remove) the fonts bundled in install.d/fonts
#
# Usage:
#   ./fonts.sh              install fonts for the current user
#   ./fonts.sh -s|--system  install system-wide for all users (uses sudo)
#   ./fonts.sh -r|--revert  uninstall the bundled fonts
#   ./fonts.sh -h|--help    show this help
#
# Fonts live in install.d/fonts/<family>/ and are copied into the font path
# with that subdirectory structure preserved, so families stay grouped and
# --revert can remove exactly what was installed and nothing else.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FONTS_SRC="${SCRIPT_DIR}/fonts"
readonly USER_FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
readonly SYSTEM_FONT_DIR="/usr/share/fonts"

# Extensions fontconfig can actually consume.
readonly FONT_EXTENSIONS=(ttf otf ttc pfb pfm bdf pcf pcf.gz)

FONT_FILES=()
DEST_DIR=""
SUDO=""

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

# --- discovery ---------------------------------------------------------------

check_environment() {
    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; use --system to install system-wide."

    [[ -d "$FONTS_SRC" ]] \
        || die "Font directory not found: ${FONTS_SRC}"
}

# Collect font paths relative to FONTS_SRC, e.g. "sf-pro/SF Pro Display Bold.otf".
# Null-delimited throughout: several bundled fonts have spaces in their names.
collect_fonts() {
    local find_args=()
    local ext

    for ext in "${FONT_EXTENSIONS[@]}"; do
        [[ ${#find_args[@]} -gt 0 ]] && find_args+=(-o)
        find_args+=(-iname "*.${ext}")
    done

    local path
    while IFS= read -r -d '' path; do
        FONT_FILES+=("${path#"${FONTS_SRC}/"}")
    done < <(find "$FONTS_SRC" -type f \( "${find_args[@]}" \) -print0 | sort -z)

    [[ ${#FONT_FILES[@]} -gt 0 ]] \
        || die "No font files found under ${FONTS_SRC}"
}

refresh_font_cache() {
    if ! command -v fc-cache >/dev/null 2>&1; then
        warn "fc-cache not found (install fontconfig); fonts copied but cache not rebuilt."
        return
    fi

    info "Rebuilding the font cache..."
    $SUDO fc-cache -f >/dev/null
}

# --- install -----------------------------------------------------------------

install_fonts() {
    local rel

    info "Installing ${#FONT_FILES[@]} font(s) into ${DEST_DIR}"

    for rel in "${FONT_FILES[@]}"; do
        $SUDO install -Dm 644 "${FONTS_SRC}/${rel}" "${DEST_DIR}/${rel}"
        printf '   %s\n' "$rel"
    done

    refresh_font_cache
    info "Done. Verify with: fc-list | grep -i biorhyme"
}

# --- revert ------------------------------------------------------------------

revert_fonts() {
    local removed=0
    local rel

    for rel in "${FONT_FILES[@]}"; do
        if [[ -f "${DEST_DIR}/${rel}" ]]; then
            $SUDO rm -f "${DEST_DIR}/${rel}"
            printf '   removed %s\n' "$rel"
            removed=$((removed + 1))
        fi
    done

    if [[ $removed -eq 0 ]]; then
        warn "No bundled fonts found in ${DEST_DIR}; nothing to remove."
        return
    fi

    # Clean up family directories left empty, but keep the font root itself.
    $SUDO find "$DEST_DIR" -mindepth 1 -type d -empty -delete

    refresh_font_cache
    info "Removed ${removed} font(s) from ${DEST_DIR}"
}

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0
    local system=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--revert) revert=1 ;;
            -s|--system) system=1 ;;
            -h|--help)   usage; exit 0 ;;
            *)           error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment

    if [[ $system -eq 1 ]]; then
        command -v sudo >/dev/null 2>&1 \
            || die "sudo not found; it is required for --system."
        DEST_DIR="$SYSTEM_FONT_DIR"
        SUDO="sudo"
        sudo -v
    else
        DEST_DIR="$USER_FONT_DIR"
        SUDO=""
    fi

    collect_fonts

    if [[ $revert -eq 1 ]]; then
        revert_fonts
    else
        install_fonts
    fi
}

main "$@"
