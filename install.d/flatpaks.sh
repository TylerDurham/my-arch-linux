# flatpaks.sh - install (or remove) the flatpaks listed in flatpaks.txt
#
# Flatpaks come from a remote rather than a repository, so this module adds
# Flathub before installing anything. It installs the flatpak package itself
# too: modules run in alphabetical order, so this one is reached before
# packages.sh on a full pass and cannot assume flatpak is already there.
#
# Environment knobs:
#   SCOPE=user      install into ~/.local/share/flatpak instead of system-wide
#   NO_CONFIRM=1    skip flatpak's and pacman's confirmation prompts

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Current directory (relative to this file)
readonly FLATPAK_LIST="${FLATPAK_LIST:-${CWD}/flatpaks.txt}"  # File listing the flatpaks to install
readonly REMOTE="flathub"                                     # Remote the listed apps come from
readonly REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
SCOPE="${SCOPE:-system}"                                      # system or user
NO_CONFIRM="${NO_CONFIRM:-0}"                                 # Skip confirmation prompts

# Array to hold flatpaks to be installed, read from $FLATPAK_LIST
FLATPAKS=()

# Set by on_init: the scope flag every flatpak call takes, and the sudo prefix
# that a system-scope call needs and a user-scope one must not have.
SCOPE_FLAG=""
SUDO=""

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

  log "$FUNCNAME: Resolving scope..."
  resolve_scope

  log "$FUNCNAME: Reading flatpak list..."
  read_flatpak_list
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing flatpak itself..."
  install_flatpak

  log "$FUNCNAME: Adding the ${REMOTE} remote..."
  add_remote

  log "$FUNCNAME: Installing ${#FLATPAKS[@]} flatpak(s) (${SCOPE} scope)..."
  install_flatpaks
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing ${#FLATPAKS[@]} flatpak(s) (${SCOPE} scope)..."
  uninstall_flatpaks

  log "$FUNCNAME: Removing unused runtimes..."
  remove_unused
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

# A user-scope install writes into the invoking user's home, so it must not be
# run through sudo; a system-scope one must be.
resolve_scope() {
    case "$SCOPE" in
        system)
            SCOPE_FLAG="--system"
            SUDO="sudo"
            ;;
        user)
            SCOPE_FLAG="--user"
            SUDO=""
            ;;
        *)
            die "SCOPE must be 'system' or 'user', not '${SCOPE}'."
            ;;
    esac
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Read the flatpak list, skipping blank lines and '#' comments.
read_flatpak_list() {
    [[ -f "$FLATPAK_LIST" ]] \
        || die "Flatpak list not found: ${FLATPAK_LIST}"

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"                  # strip trailing comments
        line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"  # trim trailing whitespace
        [[ -n "$line" ]] && FLATPAKS+=("$line")
    done < "$FLATPAK_LIST"

    [[ ${#FLATPAKS[@]} -gt 0 ]] \
        || die "No flatpaks listed in ${FLATPAK_LIST}"
}

# packages.txt also lists flatpak, but this module runs before that one on a
# full pass, so it cannot wait for it.
install_flatpak() {
    if is_installed flatpak; then
        info "flatpak already installed."
        return
    fi

    info "Installing flatpak."

    if [[ $NO_CONFIRM -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm flatpak
    else
        sudo pacman -S --needed flatpak
    fi
}

# Nothing can be installed until a remote is configured, and Arch ships none.
add_remote() {
    if $SUDO flatpak remote-list "$SCOPE_FLAG" 2>/dev/null | grep -q "^${REMOTE}\b"; then
        info "The ${REMOTE} remote is already configured (${SCOPE} scope)."
        return
    fi

    info "Adding the ${REMOTE} remote (${SCOPE} scope)..."
    $SUDO flatpak remote-add "$SCOPE_FLAG" --if-not-exists "$REMOTE" "$REMOTE_URL"
}

app_present() {
    $SUDO flatpak info "$SCOPE_FLAG" "$1" >/dev/null 2>&1
}

install_flatpaks() {
    local missing=()
    local app

    for app in "${FLATPAKS[@]}"; do
        if ! app_present "$app"; then
            missing+=("$app")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "All flatpaks already installed: ${FLATPAKS[*]}"
        return
    fi

    info "Installing from ${REMOTE}: ${missing[*]}"

    if [[ $NO_CONFIRM -eq 1 ]]; then
        $SUDO flatpak install "$SCOPE_FLAG" -y "$REMOTE" "${missing[@]}"
    else
        $SUDO flatpak install "$SCOPE_FLAG" "$REMOTE" "${missing[@]}"
    fi

    log "Installed ${#missing[@]} flatpak(s)."
}

uninstall_flatpaks() {
    local installed=()
    local app

    if ! command -v flatpak >/dev/null 2>&1; then
        warn "flatpak is not installed; nothing to remove."
        return
    fi

    for app in "${FLATPAKS[@]}"; do
        if app_present "$app"; then
            installed+=("$app")
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "None of the listed flatpaks are installed; nothing to remove."
        return
    fi

    info "Removing: ${installed[*]}"
    $SUDO flatpak uninstall "$SCOPE_FLAG" -y "${installed[@]}"

    log "Removed ${#installed[@]} flatpak(s)."
}

# Runtimes are shared, so they are only reclaimed once nothing references them.
remove_unused() {
    if ! command -v flatpak >/dev/null 2>&1; then
        return
    fi

    $SUDO flatpak uninstall "$SCOPE_FLAG" --unused -y >/dev/null 2>&1 || true
}
