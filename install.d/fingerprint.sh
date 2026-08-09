#!/usr/bin/env bash
#
# fingerprint.sh - set up a fingerprint reader and wire it into unlock prompts
#
# Usage:
#   ./fingerprint.sh                    install fprintd, enroll a finger, wire up PAM
#   ./fingerprint.sh -f|--finger NAME   enroll NAME instead of right-index-finger
#                                       (repeatable; see --list-fingers)
#   ./fingerprint.sh --list-fingers     print the finger names fprintd accepts
#   ./fingerprint.sh --enroll-only      (re-)enroll fingers, leave PAM alone
#   ./fingerprint.sh --login            also wire up the SDDM greeter (opt-in)
#   ./fingerprint.sh -s|--status        report reader, enrollments and PAM state
#   ./fingerprint.sh -r|--revert        unwire PAM and delete enrolled fingerprints
#   ./fingerprint.sh -h|--help          show this help
#
# What gets wired where:
#   sudo, polkit-1  pam_fprintd.so is added as 'sufficient' ahead of the password
#                   stack, so a scan satisfies the prompt and a password still
#                   works as fallback. polkit is what 1Password's "unlock using
#                   system authentication service" goes through.
#   hyprlock        needs no PAM change - it talks to fprintd over D-Bus itself
#                   and is configured in hyprlock.conf. This script only checks.
#
# system-auth and the TTY login stack are deliberately left alone: a mistake
# there can lock you out of every authentication path at once.

set -euo pipefail

readonly PKGS=(fprintd)
readonly DEFAULT_FINGER="right-index-finger"

# Services whose PAM stack gets the fprintd line. sddm is appended by --login.
PAM_SERVICES=(sudo polkit-1)

readonly PAM_DIR="/etc/pam.d"
readonly PAM_VENDOR_DIR="/usr/lib/pam.d"
readonly BAK_SUFFIX=".pre-fingerprint.bak"

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

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,25p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

list_fingers() {
    printf '%s\n' "${VALID_FINGERS[@]}"
}

# --- checks ------------------------------------------------------------------

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

is_valid_finger() {
    local candidate="$1" finger
    for finger in "${VALID_FINGERS[@]}"; do
        [[ "$finger" == "$candidate" ]] && return 0
    done
    return 1
}

# --- fprintd -----------------------------------------------------------------

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

# --- PAM ---------------------------------------------------------------------

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

# --- integrations we only report on -------------------------------------------

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

check_1password() {
    if ! is_installed 1password; then
        return
    fi

    # settings.json carries HMACs in "authTags"; editing it by hand invalidates
    # them, so this only ever reads.
    if [[ -f "$OP_SETTINGS" ]] && command -v jq >/dev/null 2>&1 \
       && [[ "$(jq -r '."security.authenticatedUnlock.enabled" // false' "$OP_SETTINGS")" == "true" ]]; then
        info "1Password: system authentication is already enabled."
    else
        warn "1Password: enable Settings -> Security -> 'Unlock using system"
        warn "authentication service', then lock with Ctrl+L and unlock to test."
    fi

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
    fi
}

# --- status ------------------------------------------------------------------

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

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0 status=0 enroll_only=0 login=0
    local fingers=()
    local svc

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--finger)
                [[ $# -ge 2 ]] || die "--finger needs a finger name (see --list-fingers)."
                is_valid_finger "$2" || die "Unknown finger '$2'. See --list-fingers."
                fingers+=("$2")
                shift
                ;;
            --list-fingers) list_fingers; exit 0 ;;
            --enroll-only)  enroll_only=1 ;;
            --login)        login=1 ;;
            -s|--status)    status=1 ;;
            -r|--revert)    revert=1 ;;
            -h|--help)      usage; exit 0 ;;
            *)              error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment

    [[ ${#fingers[@]} -gt 0 ]] || fingers=("$DEFAULT_FINGER")
    [[ $login -eq 1 ]] && PAM_SERVICES+=(sddm)

    if [[ $status -eq 1 ]]; then
        show_status
        exit 0
    fi

    # Prime the sudo timestamp up front so the run does not stall on a password
    # prompt in the middle of rewriting a PAM stack.
    sudo -v

    if [[ $revert -eq 1 ]]; then
        # Unwire sddm unconditionally: --login may have added it on a past run.
        for svc in "${PAM_SERVICES[@]}" sddm; do
            pam_unwire "$svc"
        done
        delete_enrollments
        info "Reverted. fprintd is still installed; remove it with: sudo pacman -Rns fprintd"
        exit 0
    fi

    install_packages

    if [[ -n "$(enrolled_fingers)" && $enroll_only -eq 0 ]]; then
        info "Already enrolled: $(enrolled_fingers | paste -sd', ' -). Use --enroll-only to add more."
    else
        enroll_fingers "${fingers[@]}"
    fi

    if [[ $enroll_only -eq 1 ]]; then
        exit 0
    fi

    verify_pam_module

    warn "About to edit PAM. Keep this shell open and test in a second terminal;"
    warn "revert with '$0 --revert' if a prompt stops accepting your password."

    for svc in "${PAM_SERVICES[@]}"; do
        pam_wire "$svc"
    done

    check_hyprlock
    check_1password

    info "Done. Test in this order: fprintd-verify, then 'sudo -k && sudo true', then 1Password."
}

main "$@"
