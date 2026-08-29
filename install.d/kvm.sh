# kvm.sh - install (or remove) the KVM/QEMU virtualisation stack
#
# KVM is the kernel side and is already there; what this installs is everything
# around it - QEMU as the userspace emulator, libvirt as the daemon that manages
# domains and networks, and virt-manager as the GUI over libvirt.
#
# Membership of the `libvirt` group is what lets you talk to the system daemon
# without sudo. It does not take effect until you log out and back in.
#
# Environment knobs:
#   QEMU_FLAVOR=qemu-full   emulate every architecture, not just this one
#   NO_CONFIRM=1            skip pacman's confirmation prompt

# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

readonly CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Current directory (relative to this file)
readonly SERVICE="libvirtd.service"                          # The libvirt system daemon
readonly LIBVIRT_GROUP="libvirt"                             # Group allowed to reach the system daemon
readonly NETWORK="default"                                   # libvirt's built-in NAT network
readonly IMAGE_DIR="/var/lib/libvirt/images"                 # Where libvirt keeps guest disks
QEMU_FLAVOR="${QEMU_FLAVOR:-qemu-desktop}"                   # qemu-desktop (this arch) or qemu-full
NO_CONFIRM="${NO_CONFIRM:-0}"                                # Skip pacman's confirmation prompt

# Packages installed alongside QEMU:
#   libvirt       the daemon virt-manager and virsh talk to
#   virt-manager  the GUI; virt-viewer is the standalone console it opens
#   dnsmasq       required by the default NAT network - without it, no guest DHCP
#   edk2-ovmf     UEFI firmware, so guests can boot something other than SeaBIOS
#   swtpm         emulated TPM 2.0, which Windows 11 guests refuse to install without
#   dmidecode     lets libvirt report the host's hardware to guests
readonly PKGS=(libvirt virt-manager virt-viewer dnsmasq edk2-ovmf swtpm dmidecode)

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

  log "$FUNCNAME: Checking for hardware virtualisation..."
  check_kvm_support

  # Prime the sudo timestamp up front so the install does not stall on a
  # password prompt halfway through.
  sudo -v
}

# Called by source script. Installs the module.
on_install() {
  log "$FUNCNAME: Installing ${QEMU_FLAVOR} and the libvirt stack..."
  install_packages

  log "$FUNCNAME: Enabling ${SERVICE}..."
  enable_service

  log "$FUNCNAME: Joining the ${LIBVIRT_GROUP} group..."
  join_libvirt_group

  log "$FUNCNAME: Starting the ${NETWORK} network..."
  start_default_network

  report_ready
}

# Called by source script. Uninstalls the module.
on_uninstall() {
  log "$FUNCNAME: Stopping the ${NETWORK} network..."
  stop_default_network

  log "$FUNCNAME: Disabling ${SERVICE}..."
  disable_service

  log "$FUNCNAME: Leaving the ${LIBVIRT_GROUP} group..."
  leave_libvirt_group

  log "$FUNCNAME: Removing packages..."
  uninstall_packages

  # Guest disks are user data; deleting them silently on an uninstall is not
  # this module's call to make.
  info "Left your guest disks in place. To reclaim that space:"
  printf '   sudo rm -rf %s\n' "$IMAGE_DIR"
}

# -------------------------------------------------------------------------------------------------
# CORE FUNCTIONS
# -------------------------------------------------------------------------------------------------

# Check for pacman and sudo, and that we are not running as root.
check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it adds your own user to the ${LIBVIRT_GROUP} group."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install packages."
}

# vmx (Intel) or svm (AMD) in /proc/cpuinfo is the hardware side of KVM. Without
# it QEMU still runs, but only under TCG emulation, which is far too slow to be
# what anyone installing this wants.
check_kvm_support() {
    grep -Eq '^flags.*\b(vmx|svm)\b' /proc/cpuinfo \
        || die "This CPU reports no vmx/svm flag, so KVM cannot accelerate anything."

    if [[ ! -e /dev/kvm ]]; then
        warn "/dev/kvm is missing even though the CPU supports virtualisation."
        warn "It is usually switched off in firmware - look for SVM, AMD-V, VT-x or"
        warn "'Intel Virtualization Technology' in the BIOS. Installing anyway; the"
        warn "stack will work once it is enabled."
    fi
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

install_packages() {
    local wanted=("$QEMU_FLAVOR" "${PKGS[@]}")
    local missing=()
    local pkg

    for pkg in "${wanted[@]}"; do
        if ! is_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Packages already present: ${wanted[*]}"
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
    local wanted=("$QEMU_FLAVOR" "${PKGS[@]}")
    local installed=()
    local pkg

    for pkg in "${wanted[@]}"; do
        if is_installed "$pkg"; then
            installed+=("$pkg")
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "No KVM packages installed; nothing to remove."
        return
    fi

    info "Removing: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"
}

enable_service() {
    sudo systemctl enable --now "$SERVICE"
}

disable_service() {
    if ! systemctl list-unit-files "$SERVICE" >/dev/null 2>&1; then
        warn "${SERVICE} not present; nothing to disable."
        return
    fi

    sudo systemctl disable --now "$SERVICE"
}

# Membership of this group is what lets virsh and virt-manager reach the system
# daemon without sudo.
join_libvirt_group() {
    if ! getent group "$LIBVIRT_GROUP" >/dev/null 2>&1; then
        warn "The ${LIBVIRT_GROUP} group does not exist; libvirt should have created it."
        return
    fi

    if id -nG "$USER" | grep -qw "$LIBVIRT_GROUP"; then
        info "${USER} is already in the ${LIBVIRT_GROUP} group."
        return
    fi

    info "Adding ${USER} to the ${LIBVIRT_GROUP} group..."
    sudo usermod -aG "$LIBVIRT_GROUP" "$USER"
    warn "Log out and back in for the new group membership to take effect."
}

leave_libvirt_group() {
    if ! id -nG "$USER" | grep -qw "$LIBVIRT_GROUP"; then
        return
    fi

    info "Removing ${USER} from the ${LIBVIRT_GROUP} group..."
    sudo gpasswd -d "$USER" "$LIBVIRT_GROUP" >/dev/null
}

# The default NAT network is what gives guests an address and a route out. It
# ships defined but inactive, and is not marked to come back after a reboot.
#
# Run through sudo rather than as the user: the group membership added above is
# not active in this session yet, so an unprivileged virsh would be refused.
start_default_network() {
    if ! sudo virsh net-info "$NETWORK" >/dev/null 2>&1; then
        warn "libvirt has no '${NETWORK}' network defined; skipping."
        return
    fi

    if sudo virsh net-info "$NETWORK" 2>/dev/null | grep -q '^Active: *yes'; then
        info "The ${NETWORK} network is already active."
    else
        info "Starting the ${NETWORK} network..."
        sudo virsh net-start "$NETWORK" >/dev/null
    fi

    sudo virsh net-autostart "$NETWORK" >/dev/null
}

stop_default_network() {
    if ! command -v virsh >/dev/null 2>&1; then
        return
    fi

    if ! sudo virsh net-info "$NETWORK" >/dev/null 2>&1; then
        return
    fi

    info "Stopping the ${NETWORK} network..."
    sudo virsh net-autostart --disable "$NETWORK" >/dev/null 2>&1 || true
    sudo virsh net-destroy "$NETWORK" >/dev/null 2>&1 || true
}

report_ready() {
    local version

    version="$(sudo virsh version --daemon 2>/dev/null | sed -n 's/^Running against daemon: //p' | head -n1)"

    if [[ -n "$version" ]]; then
        info "Done: libvirt ${version} is running."
    else
        warn "libvirt is installed but did not answer a version query; check"
        warn "'systemctl status ${SERVICE}'."
    fi

    info "Guest disks live in ${IMAGE_DIR}. Start virt-manager once you have"
    info "logged out and back in, so your ${LIBVIRT_GROUP} membership is active."
}
