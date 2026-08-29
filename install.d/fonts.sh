# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"          # Current directory (relative to this file)
readonly FONTS_SRC="${CWD}/fonts"                                     # Directory that contains fonts to be installed
readonly USER_FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts" # User font directory
readonly SYSTEM_FONT_DIR="/usr/share/fonts"                           # System font directory
readonly FONT_EXTENSIONS=(ttf otf ttc pfb pfm bdf pcf pcf.gz)         # Extensions fontconfig can actually consume.
SUDO=""
DEST_DIR="$USER_FONT_DIR"

# Array to hold fonts to be installed, read from $FONTS_SRC
FONT_FILES=()

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

  log "$FUNCNAME: Collecting fonts..."
  collect_fonts
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing ${#FONT_FILES[@]} font(s) into ${DEST_DIR}"
  install_fonts

  log "$FUNCNAME: Rebuilding font cache..."
  refresh_font_cache

  log "$FUNCNAME: Done. Verify with: fc-list | grep -i biorhyme"
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  uninstall_fonts

  log "$FUNCNAME: Rebuilding font cache..."
  refresh_font_cache
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

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

# Check if user is running sudo and that the local font directory exists.
check_environment() {
    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; use --system to install system-wide."

    [[ -d "$FONTS_SRC" ]] \
        || die "Font directory not found: ${FONTS_SRC}"
}


# Install the fonts
install_fonts() {
    local rel

    for rel in "${FONT_FILES[@]}"; do
        $SUDO install -Dm 644 "${FONTS_SRC}/${rel}" "${DEST_DIR}/${rel}"
        printf '     - %s\n' "$rel"
    done
}

# refresh font cache
refresh_font_cache() {
    if ! command -v fc-cache >/dev/null 2>&1; then
        warn "fc-cache not found (install fontconfig); fonts copied but cache not rebuilt."
        return
    fi

    $SUDO fc-cache -f >/dev/null
}


uninstall_fonts() {
    local removed=0
    local rel

    for rel in "${FONT_FILES[@]}"; do
        if [[ -f "${DEST_DIR}/${rel}" ]]; then
            $SUDO rm -f "${DEST_DIR}/${rel}"
            printf '     - removed %s\n' "$rel"
            removed=$((removed + 1))
        fi
    done

    if [[ $removed -eq 0 ]]; then
        warn "No bundled fonts found in ${DEST_DIR}; nothing to remove." | indent 4
        return
    fi

    # Clean up family directories left empty, but keep the font root itself.
    $SUDO find "$DEST_DIR" -mindepth 1 -type d -empty -delete

    log "Removed ${removed} font(s) from ${DEST_DIR}"
}
