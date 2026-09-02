# 10-plymouth.sh - install (or remove) a Plymouth boot splash
#
# Fetches a themed pack from adi1090x/plymouth-themes and sets it as the
# default Plymouth theme, wires sd-plymouth into mkinitcpio's HOOKS ahead of
# sd-encrypt (so the LUKS unlock prompt is themed too), and adds the standard
# silent-boot kernel params.
#
# /etc/kernel/cmdline is what limine-mkinitcpio reads to regenerate the Limine
# boot entry on this setup, so that - not a bootloader config file - is where
# the kernel params land.
#
# Environment knobs:
#   PLYMOUTH_PRESET=lone   which preset to install (see PRESETS below)
#   NO_CONFIRM=1           skip pacman's confirmation prompt
#
# Safe to re-run: every step checks current state before changing anything.
# Uninstall reads the currently active theme back off the system rather than
# trusting PLYMOUTH_PRESET, so it works even if that variable is not set to
# whatever was installed.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"        # Current directory (relative to this file)
readonly PKGS=(plymouth)                                            # Packages this module owns
readonly THEMES_REPO="https://github.com/adi1090x/plymouth-themes"  # Upstream theme source
readonly THEMES_DIR="/usr/share/plymouth/themes"                    # Where themes live once installed
readonly MKINITCPIO_CONF="/etc/mkinitcpio.conf"                     # HOOKS live here
readonly PLYMOUTHD_CONF="/etc/plymouth/plymouthd.conf"              # Per-theme daemon overrides
readonly CMDLINE_FILE="/etc/kernel/cmdline"                         # Read by limine-mkinitcpio
PLYMOUTH_PRESET="${PLYMOUTH_PRESET:-lone}"                          # Preset to install (see PRESETS)
NO_CONFIRM="${NO_CONFIRM:-0}"                                       # Skip pacman's confirmation prompt

# Silent-boot kernel params, fixed on - not exposed as a knob.
readonly SPLASH_PARAMS=(quiet splash loglevel=3 udev.log_level=3 systemd.show_status=auto)

# The managed block written into plymouthd.conf, and the line inside it.
readonly MARK_BEGIN="# >>> 10-plymouth.sh managed >>>"
readonly MARK_END="# <<< 10-plymouth.sh managed <<<"

# Presets: name -> "theme:extraConfig". extraConfig is a "Key=Value" line
# written to plymouthd.conf's [Daemon] section, or empty for none.
declare -A PRESETS=(
  [rings]="rings:"
  [lone]="lone:ShowDelay=0"
  [cuts]="cuts:ShowDelay=0"
  [circuit]="circuit:"
  [connect]="connect:"
)

# Resolved from PLYMOUTH_PRESET by on_init.
THEME=""
EXTRA_CONFIG=""

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

  log "$FUNCNAME: Resolving preset '${PLYMOUTH_PRESET}'..."
  resolve_preset

  # Prime the sudo timestamp up front so the install does not stall on a
  # password prompt halfway through.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing ${PKGS[*]}..."
  install_packages

  log "$FUNCNAME: Fetching theme '${THEME}'..."
  fetch_theme

  log "$FUNCNAME: Setting default theme to '${THEME}'..."
  sudo plymouth-set-default-theme "$THEME"

  log "$FUNCNAME: Writing plymouthd.conf overrides..."
  write_daemon_conf

  log "$FUNCNAME: Wiring sd-plymouth into mkinitcpio HOOKS..."
  add_hook

  log "$FUNCNAME: Adding silent-boot kernel params..."
  add_cmdline_params

  log "$FUNCNAME: Rebuilding initramfs..."
  sudo mkinitcpio -P

  info "Done: preset '${PLYMOUTH_PRESET}' (theme '${THEME}') is now the default. Reboot to see it."
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  local installed_theme
  installed_theme="$(plymouth-set-default-theme 2>/dev/null || true)"

  log "$FUNCNAME: Resetting default theme (currently '${installed_theme:-none}')..."
  reset_default_theme "$installed_theme"

  log "$FUNCNAME: Removing plymouthd.conf overrides..."
  remove_daemon_conf

  log "$FUNCNAME: Removing sd-plymouth from mkinitcpio HOOKS..."
  remove_hook

  log "$FUNCNAME: Removing silent-boot kernel params..."
  remove_cmdline_params

  log "$FUNCNAME: Removing theme files..."
  remove_theme "$installed_theme"

  log "$FUNCNAME: Removing packages..."
  uninstall_packages

  log "$FUNCNAME: Rebuilding initramfs..."
  sudo mkinitcpio -P

  info "Done: Plymouth removed and initramfs rebuilt."
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for pacman, sudo and git, and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it calls sudo where needed."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install packages and edit system files."

    command -v git >/dev/null 2>&1 \
        || die "git not found; it is required to fetch themes from ${THEMES_REPO}."
}

# Split PLYMOUTH_PRESET's "theme:extraConfig" entry into THEME/EXTRA_CONFIG.
resolve_preset() {
    [[ -n "${PRESETS[$PLYMOUTH_PRESET]+x}" ]] \
        || die "Unknown preset '${PLYMOUTH_PRESET}' (available: ${!PRESETS[*]})"

    THEME="${PRESETS[$PLYMOUTH_PRESET]%%:*}"
    EXTRA_CONFIG="${PRESETS[$PLYMOUTH_PRESET]#*:}"
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

install_packages() {
    local missing=()
    local pkg

    for pkg in "${PKGS[@]}"; do
        is_installed "$pkg" || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Packages already present: ${PKGS[*]}"
        return
    fi

    info "Installing: ${missing[*]}"

    if [[ $NO_CONFIRM -eq 1 ]]; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        sudo pacman -S --needed "${missing[@]}"
    fi
}

uninstall_packages() {
    local installed=()
    local pkg

    for pkg in "${PKGS[@]}"; do
        is_installed "$pkg" && installed+=("$pkg")
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "None of the listed packages are installed; nothing to remove."
        return
    fi

    info "Removing: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"
}

# --- theme -----------------------------------------------------------------------------------------

fetch_theme() {
    local theme_dir="${THEMES_DIR}/${THEME}"
    local tmp_dir src pack

    if [[ -d "$theme_dir" ]]; then
        info "Theme '${THEME}' already installed at ${theme_dir}."
        return
    fi

    tmp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmp_dir}'" RETURN

    info "Cloning ${THEMES_REPO}..."
    git clone --depth 1 --quiet "$THEMES_REPO" "${tmp_dir}/plymouth-themes"

    src=""
    for pack in pack_1 pack_2 pack_3; do
        if [[ -d "${tmp_dir}/plymouth-themes/${pack}/${THEME}" ]]; then
            src="${tmp_dir}/plymouth-themes/${pack}/${THEME}"
            break
        fi
    done

    [[ -n "$src" ]] \
        || die "Theme '${THEME}' not found in ${THEMES_REPO} (checked pack_1..pack_3)."

    info "Installing theme files to ${theme_dir}..."
    sudo mkdir -p "$theme_dir"
    sudo cp -r "${src}/." "${theme_dir}/"
}

# Only remove themes this module owns - one of PRESETS' values. A
# hand-installed or distro theme left as the default is not ours to delete.
remove_theme() {
    local theme="$1"
    local theme_dir="${THEMES_DIR}/${theme}"
    local preset found=0

    if [[ -z "$theme" || ! -d "$theme_dir" ]]; then
        return
    fi

    for preset in "${!PRESETS[@]}"; do
        [[ "${PRESETS[$preset]%%:*}" == "$theme" ]] && { found=1; break; }
    done

    if [[ $found -eq 0 ]]; then
        warn "Default theme '${theme}' is not one of this module's presets; leaving ${theme_dir} in place."
        return
    fi

    info "Removing ${theme_dir}"
    sudo rm -rf "$theme_dir"
}

reset_default_theme() {
    local current="$1"

    if [[ -z "$current" || "$current" == "text" ]]; then
        info "Default theme is already 'text' (or unset); nothing to reset."
        return
    fi

    info "Resetting default theme from '${current}' to 'text'"
    sudo plymouth-set-default-theme text
}

# --- plymouthd.conf ----------------------------------------------------------------------------------

write_daemon_conf() {
    local tmp

    if [[ -z "$EXTRA_CONFIG" ]]; then
        return
    fi

    tmp="$(mktemp)"
    [[ -f "$PLYMOUTHD_CONF" ]] && cp "$PLYMOUTHD_CONF" "$tmp"

    if grep -qF "$MARK_BEGIN" "$tmp" 2>/dev/null && grep -qxF "$EXTRA_CONFIG" "$tmp"; then
        info "${PLYMOUTHD_CONF} already carries '${EXTRA_CONFIG}'."
        rm -f "$tmp"
        return
    fi

    # Strip a managed block from a previous run (e.g. switching presets)
    # before appending the current one.
    strip_managed_block "$tmp"

    grep -q '^\[Daemon\]' "$tmp" || printf '[Daemon]\n' >> "$tmp"
    {
        printf '%s\n' "$MARK_BEGIN"
        printf '%s\n' "$EXTRA_CONFIG"
        printf '%s\n' "$MARK_END"
    } >> "$tmp"

    info "Setting ${EXTRA_CONFIG} in ${PLYMOUTHD_CONF}"
    sudo mkdir -p "$(dirname "$PLYMOUTHD_CONF")"
    sudo install -m 0644 -o root -g root "$tmp" "$PLYMOUTHD_CONF"
    rm -f "$tmp"
}

remove_daemon_conf() {
    local tmp

    if [[ ! -f "$PLYMOUTHD_CONF" ]] || ! grep -qF "$MARK_BEGIN" "$PLYMOUTHD_CONF"; then
        return
    fi

    tmp="$(mktemp)"
    cp "$PLYMOUTHD_CONF" "$tmp"
    strip_managed_block "$tmp"

    info "Removing managed block from ${PLYMOUTHD_CONF}"
    sudo install -m 0644 -o root -g root "$tmp" "$PLYMOUTHD_CONF"
    rm -f "$tmp"
}

# Strip the MARK_BEGIN/MARK_END block from $1 in place.
strip_managed_block() {
    local file="$1"
    local tmp
    tmp="$(mktemp)"

    awk -v begin="$MARK_BEGIN" -v end="$MARK_END" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip       { print }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

# --- mkinitcpio HOOKS --------------------------------------------------------------------------------

# sd-plymouth has to run before sd-encrypt for a themed LUKS unlock prompt.
# Fixed choice - not exposed as an option.
add_hook() {
    local hooks tmp

    [[ -f "$MKINITCPIO_CONF" ]] \
        || die "${MKINITCPIO_CONF} not found."

    hooks="$(grep -oP '^HOOKS=\(\K[^)]*' "$MKINITCPIO_CONF")"
    [[ -n "$hooks" ]] \
        || die "Could not find a HOOKS=(...) line in ${MKINITCPIO_CONF}."

    if [[ " $hooks " == *" sd-plymouth "* ]]; then
        info "sd-plymouth is already in HOOKS."
        return
    fi

    if [[ " $hooks " == *" sd-encrypt "* ]]; then
        hooks="${hooks/sd-encrypt/sd-plymouth sd-encrypt}"
    else
        hooks="$hooks sd-plymouth"
    fi

    info "Adding sd-plymouth to HOOKS in ${MKINITCPIO_CONF}"
    tmp="$(mktemp)"
    cp "$MKINITCPIO_CONF" "$tmp"
    sed -i "s|^HOOKS=(.*)|HOOKS=(${hooks})|" "$tmp"
    sudo install -m 0644 -o root -g root "$tmp" "$MKINITCPIO_CONF"
    rm -f "$tmp"
}

remove_hook() {
    local hooks tmp

    [[ -f "$MKINITCPIO_CONF" ]] || return

    hooks="$(grep -oP '^HOOKS=\(\K[^)]*' "$MKINITCPIO_CONF")"
    [[ " $hooks " == *" sd-plymouth "* ]] || return

    info "Removing sd-plymouth from HOOKS in ${MKINITCPIO_CONF}"
    hooks="$(echo " $hooks " | sed 's/ sd-plymouth / /' | xargs)"

    tmp="$(mktemp)"
    cp "$MKINITCPIO_CONF" "$tmp"
    sed -i "s|^HOOKS=(.*)|HOOKS=(${hooks})|" "$tmp"
    sudo install -m 0644 -o root -g root "$tmp" "$MKINITCPIO_CONF"
    rm -f "$tmp"
}

# --- kernel cmdline ------------------------------------------------------------------------------------

add_cmdline_params() {
    local content param tmp

    content=""
    [[ -f "$CMDLINE_FILE" ]] && content="$(cat "$CMDLINE_FILE")"

    for param in "${SPLASH_PARAMS[@]}"; do
        [[ " $content " == *" $param "* ]] || content="${content:+$content }$param"
    done

    info "Writing silent-boot params to ${CMDLINE_FILE}"
    tmp="$(mktemp)"
    printf '%s\n' "$content" > "$tmp"
    sudo mkdir -p "$(dirname "$CMDLINE_FILE")"
    sudo install -m 0644 -o root -g root "$tmp" "$CMDLINE_FILE"
    rm -f "$tmp"
}

remove_cmdline_params() {
    local content param tmp

    [[ -f "$CMDLINE_FILE" ]] || return

    content="$(cat "$CMDLINE_FILE")"
    for param in "${SPLASH_PARAMS[@]}"; do
        content="$(echo " $content " | sed "s| $param | |g" | xargs)"
    done

    info "Removing silent-boot params from ${CMDLINE_FILE}"
    tmp="$(mktemp)"
    printf '%s\n' "$content" > "$tmp"
    sudo install -m 0644 -o root -g root "$tmp" "$CMDLINE_FILE"
    rm -f "$tmp"
}
