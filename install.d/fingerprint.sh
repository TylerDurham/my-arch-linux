# fingerprint.sh - set up a fingerprint reader and wire it into unlock prompts
#
# What gets wired where:
#   sudo, polkit-1  pam_fprintd.so is added as 'sufficient' ahead of the password
#                   stack, so a scan satisfies the prompt and a password still
#                   works as fallback. polkit is what 1Password's "unlock using
#                   system authentication service" goes through.
#   hyprlock        needs no PAM change - it talks to fprintd over D-Bus itself
#                   and is configured in hyprlock.conf. This module only checks.
#
# system-auth and the TTY login stack are deliberately left alone: a mistake
# there can lock you out of every authentication path at once.
#
# Environment knobs:
#   FINGERS="right-index-finger left-thumb"   fingers to enroll (see list_fingers)
#   ENROLL_ONLY=1                             (re-)enroll fingers, leave PAM alone
#   WIRE_LOGIN=1                              also wire up the SDDM greeter (opt-in)
#
# show_status() reports the reader, enrollments and PAM state read-only. It has
# no lifecycle hook of its own, so it only runs if something calls it; on_install
# reports the same ground as it goes.

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly PKGS=(fprintd)                                      # Packages providing the fprintd stack
readonly DEFAULT_FINGER="right-index-finger"                 # Enrolled unless FINGERS says otherwise
readonly PAM_DIR="/etc/pam.d"                                # Where PAM stacks are read from
readonly PAM_VENDOR_DIR="/usr/lib/pam.d"                     # Arch's stock PAM stacks
readonly BAK_SUFFIX=".pre-fingerprint.bak"                   # Suffix for backed-up PAM stacks
FINGERS="${FINGERS:-$DEFAULT_FINGER}"                        # Space-separated fingers to enroll
ENROLL_ONLY="${ENROLL_ONLY:-0}"                              # Enroll only; do not touch PAM
WIRE_LOGIN="${WIRE_LOGIN:-0}"                                # Also wire the SDDM greeter

# Services whose PAM stack gets the fprintd line. sddm is appended by WIRE_LOGIN.
PAM_SERVICES=(sudo polkit-1)

# The managed block written into each PAM stack, and the line inside it.
readonly MARK_BEGIN="# >>> fingerprint.sh managed >>>"
readonly MARK_END="# <<< fingerprint.sh managed <<<"
readonly FPRINT_LINE="auth       sufficient   pam_fprintd.so"

readonly OP_SETTINGS="${XDG_CONFIG_HOME:-${HOME}/.config}/1Password/settings/settings.json"
readonly HYPRLOCK_CONF="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/hyprlock.conf"

# fprintd's enum; enrolling anything else fails with an unhelpful D-Bus error.
readonly VALID_FINGERS=(
    left-thumb left-index-finger left-middle-finger left-ring-finger left-little-finger
    right-thumb right-index-finger right-middle-finger right-ring-finger right-little-finger
)

# Fingers to enroll, split out of $FINGERS by on_init.
FINGER_LIST=()

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

  log "$FUNCNAME: Resolving fingers to enroll..."
  resolve_fingers

  [[ $WIRE_LOGIN -eq 1 ]] && PAM_SERVICES+=(sddm)

  # Prime the sudo timestamp up front so the run does not stall on a password
  # prompt in the middle of rewriting a PAM stack.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  local svc

  log "$FUNCNAME: Installing ${PKGS[*]}..."
  install_packages

  if [[ -n "$(enrolled_fingers)" && $ENROLL_ONLY -eq 0 ]]; then
    info "Already enrolled: $(enrolled_fingers | paste -sd', ' -). Set ENROLL_ONLY=1 to add more."
  else
    log "$FUNCNAME: Enrolling ${FINGER_LIST[*]}..."
    enroll_fingers "${FINGER_LIST[@]}"
  fi

  if [[ $ENROLL_ONLY -eq 1 ]]; then
    info "ENROLL_ONLY=1; leaving PAM alone."
    return
  fi

  verify_pam_module

  warn "About to edit PAM. Keep this shell open and test in a second terminal;"
  warn "revert with './install.sh -u -m fingerprint' if a prompt stops accepting"
  warn "your password."

  for svc in "${PAM_SERVICES[@]}"; do
    pam_wire "$svc"
  done

  check_hyprlock
  check_1password

  info "Done. Test in this order: fprintd-verify, then 'sudo -k && sudo true', then 1Password."
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  local svc

  # Unwire sddm unconditionally: WIRE_LOGIN may have added it on a past run.
  log "$FUNCNAME: Unwiring PAM..."
  for svc in "${PAM_SERVICES[@]}" sddm; do
    pam_unwire "$svc"
  done

  log "$FUNCNAME: Deleting enrollments..."
  delete_enrollments

  info "Reverted. fprintd is still installed; remove it with: sudo pacman -Rns fprintd"
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for pacman and sudo, and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; fingerprints enroll against your own user."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install packages and edit PAM."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

list_fingers() {
    printf '%s\n' "${VALID_FINGERS[@]}"
}

is_valid_finger() {
    local candidate="$1" finger
    for finger in "${VALID_FINGERS[@]}"; do
        [[ "$finger" == "$candidate" ]] && return 0
    done
    return 1
}

# Split $FINGERS into FINGER_LIST, rejecting names fprintd does not accept.
resolve_fingers() {
    local finger

    read -ra FINGER_LIST <<<"$FINGERS"

    [[ ${#FINGER_LIST[@]} -gt 0 ]] \
        || die "FINGERS is empty; set it to one or more finger names."

    for finger in "${FINGER_LIST[@]}"; do
        is_valid_finger "$finger" \
            || die "Unknown finger '${finger}'. Valid names: ${VALID_FINGERS[*]}"
    done
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
    sudo pacman -S --needed --noconfirm "${missing[@]}"
}

# fprintd is D-Bus activated, so this both starts it and proves a reader exists.
reader_present() {
    fprintd-list "$USER" 2>&1 | grep -q "^found [1-9]"
}

require_reader() {
    if reader_present; then
        return
    fi

    error "fprintd sees no fingerprint reader."
    warn  "Check that the device shows up at all:"
    warn  "    lsusb | grep -i -E 'finger|goodix|synaptic|validity|elan'   (pacman -S usbutils)"
    warn  "    dmesg | grep -i fingerprint"
    warn  "Some readers (notably Validity/Synaptics 138a:0097 and several Goodix"
    warn  "parts) are unsupported by stock libfprint and need an AUR driver such"
    warn  "as python-validity or libfprint-tod plus a vendor TOD module."
    exit 1
}

enrolled_fingers() {
    fprintd-list "$USER" 2>/dev/null | sed -n 's/^ *- #[0-9]*: *//p'
}

enroll_fingers() {
    local fingers=("$@")
    local finger

    require_reader

    for finger in "${fingers[@]}"; do
        info "Enrolling ${finger} - scan it repeatedly until fprintd says enroll-completed."
        if ! fprintd-enroll -f "$finger" "$USER"; then
            die "Enrollment of ${finger} failed. Nothing was written to PAM; re-run to retry."
        fi
    done

    info "Enrolled: $(enrolled_fingers | paste -sd', ' -)"
    info "Verify any time with: fprintd-verify"
}

delete_enrollments() {
    if ! command -v fprintd-delete >/dev/null 2>&1; then
        warn "fprintd is not installed; no enrollments to delete."
        return
    fi

    if [[ -z "$(enrolled_fingers)" ]]; then
        info "No enrolled fingerprints for ${USER}."
        return
    fi

    info "Deleting all enrolled fingerprints for ${USER}..."
    fprintd-delete "$USER"
}

# --- PAM -----------------------------------------------------------------------------------------

# Arch ships stock PAM stacks in /usr/lib/pam.d; a file in /etc/pam.d replaces
# (does not merge with) the vendor one, so we seed from the vendor copy.
pam_source_for() {
    local svc="$1"

    if [[ -f "${PAM_DIR}/${svc}" ]]; then
        printf '%s\n' "${PAM_DIR}/${svc}"
    elif [[ -f "${PAM_VENDOR_DIR}/${svc}" ]]; then
        printf '%s\n' "${PAM_VENDOR_DIR}/${svc}"
    fi
}

pam_is_wired() {
    local svc="$1"
    [[ -f "${PAM_DIR}/${svc}" ]] && grep -qF "$MARK_BEGIN" "${PAM_DIR}/${svc}"
}

pam_wire() {
    local svc="$1"
    local src target tmp
    local from_vendor=0

    src="$(pam_source_for "$svc")"
    target="${PAM_DIR}/${svc}"

    if [[ -z "$src" ]]; then
        warn "No PAM stack found for '${svc}' in ${PAM_DIR} or ${PAM_VENDOR_DIR}; skipping."
        return
    fi

    if pam_is_wired "$svc"; then
        info "${target} already carries the fprintd line."
        return
    fi

    [[ "$src" == "${PAM_VENDOR_DIR}/"* ]] && from_vendor=1

    # Only back up a pre-existing /etc file - a vendor-seeded one reverts by
    # simply being deleted, and a stale backup would defeat that.
    if [[ $from_vendor -eq 0 && ! -f "${target}${BAK_SUFFIX}" ]]; then
        info "Backing up ${target} -> ${target}${BAK_SUFFIX}"
        sudo cp -a "$target" "${target}${BAK_SUFFIX}"
    fi

    tmp="$(mktemp)"

    # pam_fprintd has to precede the password stack for a scan to short-circuit
    # it, but must stay below any leading '#%PAM-1.0' magic comment.
    awk -v begin="$MARK_BEGIN" -v line="$FPRINT_LINE" -v end="$MARK_END" '
        NR == 1 && $0 ~ /^#%PAM/ { print; print begin; print line; print end; next }
        NR == 1                  { print begin; print line; print end; print; next }
        { print }
    ' "$src" > "$tmp"

    info "Wiring fprintd into ${target}"
    sudo install -m 0644 -o root -g root "$tmp" "$target"
    rm -f "$tmp"
}

pam_unwire() {
    local svc="$1"
    local target="${PAM_DIR}/${svc}"
    local tmp

    if [[ ! -f "$target" ]]; then
        return
    fi

    if [[ -f "${target}${BAK_SUFFIX}" ]]; then
        info "Restoring ${target} from backup"
        sudo mv -f "${target}${BAK_SUFFIX}" "$target"
        return
    fi

    if ! pam_is_wired "$svc"; then
        return
    fi

    # No backup and the file is ours: if a vendor stack exists, dropping the
    # /etc copy restores the distro default exactly.
    if [[ -f "${PAM_VENDOR_DIR}/${svc}" ]]; then
        info "Removing ${target} (falls back to ${PAM_VENDOR_DIR}/${svc})"
        sudo rm -f "$target"
        return
    fi

    tmp="$(mktemp)"
    awk -v begin="$MARK_BEGIN" -v end="$MARK_END" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        !skip       { print }
    ' "$target" > "$tmp"

    info "Stripping the fprintd line from ${target}"
    sudo install -m 0644 -o root -g root "$tmp" "$target"
    rm -f "$tmp"
}

verify_pam_module() {
    local found
    found="$(find /usr/lib/security /lib/security -name pam_fprintd.so -print -quit 2>/dev/null || true)"

    [[ -n "$found" ]] \
        || die "pam_fprintd.so is missing even though fprintd is installed; refusing to edit PAM."
}

# --- integrations we only report on ---------------------------------------------------------------

check_hyprlock() {
    if ! is_installed hyprlock; then
        return
    fi

    if [[ ! -f "$HYPRLOCK_CONF" ]]; then
        warn "hyprlock is installed but ${HYPRLOCK_CONF} was not found."
        warn "Add a fingerprint block to it (hyprlock scans via fprintd, not PAM):"
        printf '\n    auth {\n        fingerprint {\n            enabled = true\n        }\n    }\n\n'
        return
    fi

    if grep -qE '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*true' "$HYPRLOCK_CONF" \
       && grep -q 'fingerprint' "$HYPRLOCK_CONF"; then
        info "hyprlock: fingerprint block already enabled in ${HYPRLOCK_CONF}."
    else
        warn "hyprlock: no enabled fingerprint block found in ${HYPRLOCK_CONF}. Add:"
        printf '\n    auth {\n        fingerprint {\n            enabled = true\n            ready_message = Scan fingerprint to unlock\n            present_message = Scanning fingerprint\n            retry_delay = 250\n        }\n    }\n\n'
    fi
}

# 1Password re-evaluates whether it can actually use system auth every time it
# renders the lock screen and logs the verdict. That status - not the settings
# toggle - is what gates fingerprint unlock.
#
# Prefer the app's own log: only an instance started by the systemd user unit
# lands in the journal, and one launched from a launcher or a shell does not, so
# the journal happily serves a verdict from a long-dead process. Empty means the
# lock screen has not rendered since the log rolled - lock the app to get one.
# Exits non-zero when there is no match; call with '|| true'.
op_sysauth_status() {
    local log="${XDG_CONFIG_HOME:-${HOME}/.config}/1Password/logs/1Password_rCURRENT.log"

    if [[ -r "$log" ]] && grep -q 'Sys auth status' "$log" 2>/dev/null; then
        grep -o 'Sys auth status [A-Za-z]*' "$log" | tail -n1 | awk '{print $NF}'
        return
    fi

    journalctl -t 1password --since "24 hours ago" --no-pager 2>/dev/null \
        | grep -o 'Sys auth status [A-Za-z]*' \
        | tail -n1 \
        | awk '{print $NF}'
}

check_1password() {
    local sysauth

    if ! is_installed 1password; then
        return
    fi

    # settings.json carries HMACs in "authTags"; editing it by hand invalidates
    # them, so this only ever reads.
    if [[ -f "$OP_SETTINGS" ]] && command -v jq >/dev/null 2>&1 \
       && [[ "$(jq -r '."security.authenticatedUnlock.enabled" // false' "$OP_SETTINGS")" == "true" ]]; then
        info "1Password: 'Unlock using system authentication service' is switched on."
    else
        warn "1Password: enable Settings -> Security -> 'Unlock using system"
        warn "authentication service', then lock with Ctrl+L and unlock to test."
    fi

    # The toggle only records intent. A switched-on toggle sitting on top of a
    # 'NotSetup' status is the failure mode that reads as success: every piece of
    # OS plumbing below can be verified working while unlock still never happens.
    sysauth="$(op_sysauth_status || true)"
    case "$sysauth" in
        Ready)
            info "1Password: system unlock reports Ready."
            ;;
        '')
            warn "1Password: no 'Sys auth status' line in the last 24h of logs, so"
            warn "there is nothing to judge yet. Lock with Ctrl+L, then re-run show_status."
            ;;
        *)
            warn "1Password: system unlock reports '${sysauth}' despite the toggle being on."
            warn "This is a 1Password-side state problem; PAM and polkit can be fully"
            warn "working and it will still refuse. Confirm the OS side first:"
            warn "    pkcheck --action-id com.1password.1Password.unlock --process \$\$ -u"
            warn "If that accepts a scan, quit 1Password completely (a tray close is not"
            warn "enough) and toggle system authentication off and back on to rebuild"
            warn "its unlock key - re-adding the key without a restart does not stick:"
            warn "    systemctl --user stop app-1password@autostart.service"
            ;;
    esac

    [[ -f /usr/share/polkit-1/actions/com.1password.1Password.policy ]] \
        || warn "1Password's polkit policy is missing; reinstall the 1password package."

    # No agent means no prompt at all: polkit has nobody to ask, so 1Password's
    # system unlock fails before pam_fprintd is ever reached.
    if ! pgrep -f 'polkit.*authentication-agent|hyprpolkitagent' >/dev/null 2>&1; then
        warn "No polkit authentication agent is running - without one, polkit cannot"
        warn "prompt you and 1Password's system unlock will not work at all. Start one:"
        if is_installed polkit-kde-agent; then
            warn "    systemctl --user enable --now plasma-polkit-agent.service"
        elif is_installed hyprpolkitagent; then
            warn "    systemctl --user enable --now hyprpolkitagent.service"
        else
            warn "    pacman -S polkit-kde-agent  (then enable plasma-polkit-agent.service)"
        fi
    elif pgrep -f hyprpolkitagent >/dev/null 2>&1; then
        # hyprpolkitagent has no fingerprint-specific UI, so it renders a bare
        # password box and never says "place your finger". The scan still works:
        # pam_fprintd is 'sufficient' and short-circuits the stack, dismissing the
        # dialog on a match. A password-only prompt is not evidence of failure.
        info "polkit agent: hyprpolkitagent (shows a password box only; scanning"
        info "               still works and dismisses the dialog on a match)."
    fi
}

# --- status ---------------------------------------------------------------------------------------

# Read-only report of reader, enrollments and PAM state. Not wired to a hook.
show_status() {
    local svc fingers

    if is_installed fprintd; then
        info "fprintd: installed ($(pacman -Q fprintd | awk '{print $2}'))"

        if reader_present; then
            info "reader: $(fprintd-list "$USER" 2>/dev/null | sed -n 's/^Device at //p' | head -n1)"
        else
            warn "reader: none detected"
        fi

        fingers="$(enrolled_fingers | paste -sd', ' -)"
        if [[ -n "$fingers" ]]; then
            info "enrolled: ${fingers}"
        else
            warn "enrolled: none"
        fi
    else
        warn "fprintd: not installed (so no reader or enrollments to report)"
    fi

    for svc in "${PAM_SERVICES[@]}" sddm; do
        if pam_is_wired "$svc"; then
            info "pam/${svc}: wired"
        else
            warn "pam/${svc}: not wired"
        fi
    done

    check_hyprlock
    check_1password
}
