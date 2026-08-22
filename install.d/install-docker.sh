#!/usr/bin/env bash
#
# install-docker.sh - install (or remove) Docker
#
# Usage:
#   ./install-docker.sh              install the system-wide daemon (rootful)
#   ./install-docker.sh --rootless   run the daemon as your own user instead
#   ./install-docker.sh --no-prune   skip the weekly "docker system prune" timer
#   ./install-docker.sh -r|--revert  uninstall Docker and undo this script's changes
#   ./install-docker.sh -h|--help    show this help
#
# Rootful is the default and needs your account in the `docker` group, which is
# equivalent to passwordless root on this machine. --rootless runs dockerd as
# you inside a user namespace, so a container escape lands on an unprivileged
# uid; it costs an AUR build, since docker-rootless-extras is not in [extra].
#
# Revert removes the packages and everything this script wrote, but never
# deletes image/volume data; it prints the paths so you can decide.

set -euo pipefail

readonly PKGS_REPO=(docker docker-buildx docker-compose)

# Not in [extra]. rootlesskit comes in as a hard dependency; slirp4netns is the
# recommended network driver and fuse-overlayfs the storage fallback, both of
# which the package only lists as optional.
readonly PKGS_AUR=(docker-rootless-extras slirp4netns fuse-overlayfs)

# 65536 sub-ids is the conventional per-user range; rootless docker maps
# container uids into it via newuidmap(1).
readonly SUBID_START=100000
readonly SUBID_COUNT=65536

readonly CONTEXT_NAME="rootless"

# Prune weekly, but only reap what has gone a week untouched - a bare
# `prune -af` would delete images you pulled this morning just because nothing
# happens to be running them.
readonly PRUNE_AGE="168h"
readonly PRUNE_UNIT="docker-prune"

readonly USER_UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
readonly SYSTEM_UNIT_DIR="/etc/systemd/system"

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,19p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

# --- checks ------------------------------------------------------------------

check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; it configures Docker for your own user."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install packages."
}

check_rootless_support() {
    [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]] \
        || die "XDG_RUNTIME_DIR is unset; log in on a normal systemd session or drop --rootless."

    local max_userns="/proc/sys/user/max_user_namespaces"
    if [[ -r "$max_userns" && "$(< "$max_userns")" -eq 0 ]]; then
        die "Unprivileged user namespaces are disabled (${max_userns} is 0); rootless Docker cannot run."
    fi

    command -v yay >/dev/null 2>&1 \
        || die "yay not found; docker-rootless-extras is an AUR package. Run ./yay.sh first."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# --- install -----------------------------------------------------------------

# install_packages <helper> <pkg>... - install only what is genuinely missing,
# in one call. The helper is pacman or yay; yay declines to run under sudo, so
# only the pacman branch gets it.
install_packages() {
    local helper="$1"; shift
    local missing=()
    local pkg

    for pkg in "$@"; do
        is_installed "$pkg" || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Packages already present: $*"
        return
    fi

    info "Installing packages: ${missing[*]}"
    if [[ "$helper" == "yay" ]]; then
        yay -S --needed --noconfirm "${missing[@]}"
    else
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi
}

# Arch's useradd does not allocate sub-id ranges, and rootless docker refuses to
# start without them. This is the shadow-native equivalent of the /etc/subuid
# hand-edit that docker-rootless-extras prints on install.
ensure_subids() {
    if grep -q "^${USER}:" /etc/subuid 2>/dev/null && grep -q "^${USER}:" /etc/subgid 2>/dev/null; then
        info "Sub-uid/sub-gid ranges already allocated for ${USER}."
        return
    fi

    local range="${SUBID_START}-$((SUBID_START + SUBID_COUNT - 1))"

    info "Allocating sub-uid/sub-gid range ${range} for ${USER}..."
    sudo usermod --add-subuids "$range" --add-subgids "$range" "$USER"
}

# A context lives in ~/.docker and applies to every shell, unlike DOCKER_HOST,
# which only reaches processes that inherit it.
select_rootless_context() {
    local socket="unix:///run/user/$(id -u)/docker.sock"

    if docker context inspect "$CONTEXT_NAME" >/dev/null 2>&1; then
        info "Docker context '${CONTEXT_NAME}' already exists."
    else
        info "Creating the '${CONTEXT_NAME}' docker context -> ${socket}"
        docker context create "$CONTEXT_NAME" --docker "host=${socket}" >/dev/null
    fi

    docker context use "$CONTEXT_NAME" >/dev/null
}

install_prune_timer_rootless() {
    info "Installing the weekly prune timer (user scope)..."

    mkdir -p "$USER_UNIT_DIR"

    # The unit runs outside any shell, so it cannot pick up the docker context;
    # point it at the socket directly. %t is /run/user/<uid> in user scope.
    cat > "${USER_UNIT_DIR}/${PRUNE_UNIT}.service" <<EOF
[Unit]
Description=Prune unused Docker data (rootless)
Requires=docker.socket
After=docker.socket

[Service]
Type=oneshot
Environment=DOCKER_HOST=unix://%t/docker.sock
ExecStart=/usr/bin/docker system prune -af --filter until=${PRUNE_AGE}
EOF

    cat > "${USER_UNIT_DIR}/${PRUNE_UNIT}.timer" <<EOF
[Unit]
Description=Weekly Docker prune (rootless)

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "${PRUNE_UNIT}.timer"
}

install_prune_timer_rootful() {
    info "Installing the weekly prune timer (system scope)..."

    sudo tee "${SYSTEM_UNIT_DIR}/${PRUNE_UNIT}.service" >/dev/null <<EOF
[Unit]
Description=Prune unused Docker data
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker system prune -af --filter until=${PRUNE_AGE}
EOF

    sudo tee "${SYSTEM_UNIT_DIR}/${PRUNE_UNIT}.timer" >/dev/null <<EOF
[Unit]
Description=Weekly Docker prune

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now "${PRUNE_UNIT}.timer"
}

install_rootful() {
    local prune="$1"

    install_packages pacman "${PKGS_REPO[@]}"

    if id -nG "$USER" | grep -qw docker; then
        info "${USER} is already in the docker group."
    else
        warn "Members of the 'docker' group can trivially become root; --rootless avoids that."
        info "Adding ${USER} to the docker group..."
        sudo usermod -aG docker "$USER"
        warn "Log out and back in for the new group membership to take effect."
    fi

    info "Enabling the system daemon..."
    sudo systemctl enable --now docker.service

    if [[ $prune -eq 1 ]]; then
        install_prune_timer_rootful
    fi

    info "Done: Docker $(sudo docker version --format '{{.Server.Version}}' 2>/dev/null) running system-wide."
}

install_rootless() {
    local prune="$1"

    check_rootless_support

    install_packages pacman "${PKGS_REPO[@]}"
    install_packages yay "${PKGS_AUR[@]}"

    ensure_subids

    # Both daemons can coexist - they bind different sockets - but running the
    # system one alongside this is almost never what you want.
    if systemctl is-enabled docker.service >/dev/null 2>&1; then
        warn "The system-wide docker.service is also enabled; disable it with:"
        warn "   sudo systemctl disable --now docker.service docker.socket"
    fi

    # Without lingering the daemon dies with your last session, taking any
    # restart-always containers with it.
    info "Enabling lingering so the daemon survives logout..."
    sudo loginctl enable-linger "$USER"

    # docker-rootless-extras ships the user units and prefers socket activation.
    info "Starting the rootless daemon..."
    systemctl --user daemon-reload
    systemctl --user enable --now docker.socket

    select_rootless_context

    docker info >/dev/null 2>&1 \
        || die "The daemon did not come up; check 'systemctl --user status docker'."

    if [[ $prune -eq 1 ]]; then
        install_prune_timer_rootless
    fi

    info "Done: Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null) running rootless as ${USER}."
}

# --- revert ------------------------------------------------------------------

# Tear down both modes: whichever one is not installed simply has nothing to do.
revert_rootless() {
    local unit

    for unit in "${PRUNE_UNIT}.timer" docker.socket docker.service; do
        if systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
            info "Stopping user unit ${unit}..."
            systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        fi
    done

    for unit in "${PRUNE_UNIT}.service" "${PRUNE_UNIT}.timer"; do
        if [[ -f "${USER_UNIT_DIR}/${unit}" ]]; then
            rm -f "${USER_UNIT_DIR}/${unit}"
            printf '   removed %s\n' "${USER_UNIT_DIR}/${unit}"
        fi
    done

    if command -v docker >/dev/null 2>&1 && docker context inspect "$CONTEXT_NAME" >/dev/null 2>&1; then
        info "Removing the '${CONTEXT_NAME}' docker context..."
        docker context use default >/dev/null 2>&1 || true
        docker context rm "$CONTEXT_NAME" >/dev/null 2>&1 || true
    fi

    systemctl --user daemon-reload 2>/dev/null || true
}

revert_rootful() {
    local unit

    for unit in "${PRUNE_UNIT}.timer" docker.service docker.socket containerd.service; do
        if systemctl is-enabled "$unit" >/dev/null 2>&1; then
            info "Stopping system unit ${unit}..."
            sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
        fi
    done

    for unit in "${PRUNE_UNIT}.service" "${PRUNE_UNIT}.timer"; do
        if [[ -f "${SYSTEM_UNIT_DIR}/${unit}" ]]; then
            sudo rm -f "${SYSTEM_UNIT_DIR}/${unit}"
            printf '   removed %s\n' "${SYSTEM_UNIT_DIR}/${unit}"
        fi
    done

    if id -nG "$USER" | grep -qw docker; then
        info "Removing ${USER} from the docker group..."
        sudo gpasswd -d "$USER" docker >/dev/null
    fi

    sudo systemctl daemon-reload
}

remove_packages() {
    local installed=()
    local pkg

    for pkg in "${PKGS_AUR[@]}" "${PKGS_REPO[@]}"; do
        is_installed "$pkg" && installed+=("$pkg")
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "No Docker packages installed; nothing to remove."
        return
    fi

    info "Removing packages: ${installed[*]}"
    sudo pacman -Rns --noconfirm "${installed[@]}"
}

revert_docker() {
    revert_rootless
    revert_rootful
    remove_packages

    # Images and volumes are user data; deleting them silently on an uninstall
    # is not this script's call to make.
    info "Left your image/volume data in place. To reclaim it:"
    printf '   rm -rf %s/docker\n' "${XDG_DATA_HOME:-${HOME}/.local/share}"
    printf '   sudo rm -rf /var/lib/docker /var/lib/containerd\n'
    info "Left the sub-id ranges and lingering alone; podman and friends share them."
}

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0
    local rootless=0
    local prune=1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--revert) revert=1 ;;
            --rootless)  rootless=1 ;;
            --no-prune)  prune=0 ;;
            -h|--help)   usage; exit 0 ;;
            *)           error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment

    # Prime the sudo timestamp up front so the install does not stall on a
    # password prompt halfway through.
    sudo -v

    if [[ $revert -eq 1 ]]; then
        revert_docker
    elif [[ $rootless -eq 1 ]]; then
        install_rootless "$prune"
    else
        install_rootful "$prune"
    fi
}

main "$@"
