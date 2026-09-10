# 11-autologin.sh - enable (or disable) console autologin on tty1
#
# LUKS full-disk encryption already gates boot behind the disk passphrase (via
# mkinitcpio's sd-encrypt hook), so a second password at the getty login
# prompt is redundant on a single-user machine - by the time tty1 starts, the
# volume is already unlocked. This drops a systemd override under
# getty@tty1.service.d that autologins the given user instead.
#
# Environment knobs:
#   AUTOLOGIN_USER=$USER   which user to autologin (defaults to the user
#                           running this script)
#
# Safe to re-run: the override is only rewritten if its content changed.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"          # Current directory (relative to this file)
readonly GETTY_DROPIN_DIR="/etc/systemd/system/getty@tty1.service.d" # systemd drop-in dir for tty1's getty
readonly GETTY_DROPIN_FILE="${GETTY_DROPIN_DIR}/autologin.conf"      # Override file this module owns
AUTOLOGIN_USER="${AUTOLOGIN_USER:-$USER}"                            # User to autologin on tty1

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

  # Prime the sudo timestamp up front so the install does not stall on a
  # password prompt halfway through.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Enabling autologin for '${AUTOLOGIN_USER}' on tty1..."
  write_dropin

  log "$FUNCNAME: Reloading systemd units..."
  sudo systemctl daemon-reload

  info "Done: '${AUTOLOGIN_USER}' will autologin on tty1. Reboot (or restart getty@tty1) to see it."
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Removing autologin override..."
  remove_dropin

  log "$FUNCNAME: Reloading systemd units..."
  sudo systemctl daemon-reload

  info "Done: tty1 goes through the normal login prompt again."
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for systemd and sudo, that we are not running as root, and that the
# target user actually exists.
check_environment() {
    command -v systemctl >/dev/null 2>&1 \
        || die "systemctl not found - this module only supports systemd systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it calls sudo where needed."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to edit system files."

    id "$AUTOLOGIN_USER" >/dev/null 2>&1 \
        || die "User '${AUTOLOGIN_USER}' does not exist."
}

# Write the getty@tty1 override, but only if its content changed.
write_dropin() {
    local tmp
    tmp="$(mktemp)"

    # $TERM is left unescaped-from-bash (\$TERM) so systemd substitutes it
    # from the getty's own environment at start time, not with whatever
    # $TERM happens to be set to while this installer runs.
    cat > "$tmp" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${AUTOLOGIN_USER} --noclear %I \$TERM
EOF

    if [[ -f "$GETTY_DROPIN_FILE" ]] && diff -q "$tmp" "$GETTY_DROPIN_FILE" >/dev/null 2>&1; then
        info "${GETTY_DROPIN_FILE} already autologins '${AUTOLOGIN_USER}'."
        rm -f "$tmp"
        return
    fi

    info "Writing ${GETTY_DROPIN_FILE}"
    sudo mkdir -p "$GETTY_DROPIN_DIR"
    sudo install -m 0644 -o root -g root "$tmp" "$GETTY_DROPIN_FILE"
    rm -f "$tmp"
}

# Remove the override file this module owns, and the drop-in dir if it is
# now empty.
remove_dropin() {
    if [[ ! -f "$GETTY_DROPIN_FILE" ]]; then
        warn "${GETTY_DROPIN_FILE} not found; nothing to remove."
        return
    fi

    info "Removing ${GETTY_DROPIN_FILE}"
    sudo rm -f "$GETTY_DROPIN_FILE"
    sudo rmdir --ignore-fail-on-non-empty "$GETTY_DROPIN_DIR" 2>/dev/null || true
}
