#!/usr/bin/env bash
#
# claude-desktop.sh - build and install Anthropic's Claude desktop app for Linux
#
# Usage:
#   ./claude-desktop.sh                      build and install the latest release
#   ./claude-desktop.sh -V|--version VER     build VER instead of the latest release
#   ./claude-desktop.sh -p|--print-pkgbuild  print the generated PKGBUILD and exit
#   ./claude-desktop.sh -k|--keep-build      leave the build directory in place
#   ./claude-desktop.sh -s|--status          report installed vs latest upstream version
#   ./claude-desktop.sh -r|--revert          uninstall claude-desktop
#   ./claude-desktop.sh -h|--help            show this help
#
# Anthropic ships the Linux app only as a .deb in their own apt repo, so there
# is nothing for pacman to install directly. This script reads that apt index
# for the newest version and its checksum, generates a PKGBUILD that repackages
# the .deb payload, and builds it with makepkg. The result is a real pacman
# package that 'pacman -Rns claude-desktop' removes cleanly, instead of a pile
# of files unpacked into /opt that nothing owns.
#
# Only the .deb's file payload (data.tar.*) is used. Its maintainer scripts are
# Debian-specific - they register Anthropic's apt repo and add an AppArmor
# exception for Ubuntu's user-namespace restriction - and are deliberately not
# reproduced here.
#
# The package name matches the AUR's 'claude-desktop', so this and that package
# upgrade over each other rather than conflicting.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PKGNAME="claude-desktop"
readonly APT_BASE="https://downloads.claude.ai/claude-desktop/apt/stable"
readonly BUILD_ROOT="${XDG_CACHE_HOME:-${HOME}/.cache}/my-arch-linux"

# The .deb is ~170 MB, so the build directory lives under the cache dir rather
# than /tmp, which is a size-capped tmpfs on most Arch installs.
BUILD_DIR=""
KEEP_BUILD=0

# --- output helpers ----------------------------------------------------------

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
    sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

cleanup() {
    if [[ $KEEP_BUILD -eq 1 && -n "$BUILD_DIR" ]]; then
        info "Build directory kept at ${BUILD_DIR}"
        return
    fi

    if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}

# --- checks ------------------------------------------------------------------

check_environment() {
    command -v pacman >/dev/null 2>&1 \
        || die "pacman not found - this script only supports Arch-based systems."

    [[ $EUID -ne 0 ]] \
        || die "Do not run this script as root; makepkg refuses to build as root."

    command -v sudo >/dev/null 2>&1 \
        || die "sudo not found; it is required to install the built package."

    command -v makepkg >/dev/null 2>&1 \
        || die "makepkg not found. Install base-devel, or run ${SCRIPT_DIR}/yay.sh first."

    command -v curl >/dev/null 2>&1 \
        || die "curl not found; it is required to read Anthropic's apt index."
}

is_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

installed_version() {
    pacman -Q "$PKGNAME" 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//'
}

# Debian's architecture names, which is how the .deb files are named.
deb_arch() {
    case "$(uname -m)" in
        x86_64)  printf 'amd64\n' ;;
        aarch64) printf 'arm64\n' ;;
        *)       die "Unsupported architecture '$(uname -m)'; Anthropic publishes amd64 and arm64 only." ;;
    esac
}

# --- upstream apt index ------------------------------------------------------

# The index is stanza-based RFC822: blank-line-separated blocks of "Key: value".
# Every published version is listed, not just the newest, so emit them all as
# "version<TAB>sha256" and let the caller pick.
index_entries() {
    local arch="$1"

    curl -fsSL "${APT_BASE}/dists/stable/main/binary-${arch}/Packages" \
        | awk -v pkg="$PKGNAME" '
            function flush() {
                if (name == pkg && ver != "" && sha != "") print ver "\t" sha
                name = ""; ver = ""; sha = ""
            }
            /^Package:/ { name = $2 }
            /^Version:/ { ver  = $2 }
            /^SHA256:/  { sha  = $2 }
            /^[[:space:]]*$/ { flush() }
            END { flush() }
        '
}

# vercmp ships with pacman and knows Arch version ordering; the apt index is not
# sorted, and string comparison gets versions like 1.9.0 vs 1.30096.1 wrong.
latest_entry() {
    local entries="$1"
    local best_ver="" best_sha="" ver sha

    while IFS=$'\t' read -r ver sha; do
        [[ -n "$ver" ]] || continue
        if [[ -z "$best_ver" ]] || [[ "$(vercmp "$ver" "$best_ver")" -gt 0 ]]; then
            best_ver="$ver"
            best_sha="$sha"
        fi
    done <<< "$entries"

    [[ -n "$best_ver" ]] || die "No ${PKGNAME} entries found in Anthropic's apt index."

    printf '%s\t%s\n' "$best_ver" "$best_sha"
}

# Look up one specific version, so --version still gets a verified checksum
# rather than downloading unchecked.
entry_for_version() {
    local entries="$1" want="$2"
    local ver sha

    while IFS=$'\t' read -r ver sha; do
        if [[ "$ver" == "$want" ]]; then
            printf '%s\t%s\n' "$ver" "$sha"
            return
        fi
    done <<< "$entries"

    die "Version '${want}' is not in Anthropic's apt index. Available: $(cut -f1 <<< "$entries" | tr '\n' ' ')"
}

resolve_entry() {
    local want="$1"
    local entries

    entries="$(index_entries "$(deb_arch)")" \
        || die "Could not read Anthropic's apt index at ${APT_BASE}."

    if [[ -n "$want" ]]; then
        entry_for_version "$entries" "$want"
    else
        latest_entry "$entries"
    fi
}

# --- PKGBUILD ----------------------------------------------------------------

# Runtime dependencies come from the .deb's "Depends:" field translated to Arch
# names (Debian and Arch name the same libraries differently, e.g. libgtk-3-0 ->
# gtk3), plus the libraries the shipped binaries link directly. alsa-lib is only
# a Debian "Recommends:", but Chromium needs it for audio, so it is hard here.
#
# Some of these are reached by dlopen(), by spawning a program, or over D-Bus
# rather than through an ELF header - they are needed even though nothing links
# them.
write_pkgbuild() {
    local dir="$1" version="$2" sha256="$3"

    # makepkg keys sha256sums by architecture and only checks the running one,
    # so we carry just the checksum the apt index gave us for this machine.
    local sums_arch
    sums_arch="$(uname -m)"

    cat > "${dir}/PKGBUILD" <<PKGBUILD
# Generated by install.d/claude-desktop.sh - edits here are overwritten.

pkgname=${PKGNAME}
pkgver=${version}
pkgrel=1
pkgdesc="Official Claude desktop app for Linux from Anthropic"
arch=('x86_64' 'aarch64')
url="https://claude.com/download"
license=('LicenseRef-Proprietary')

depends=('alsa-lib'
         'at-spi2-core'
         'cairo'
         'dbus'
         'expat'
         'gcc-libs'
         'glib2'
         'glibc'
         'gtk3'
         'hicolor-icon-theme'
         'libcap-ng'
         'libcups'
         'libdrm'
         'libnotify'
         'libseccomp'
         'libsecret'
         'libx11'
         'libxcb'
         'libxcomposite'
         'libxdamage'
         'libxext'
         'libxfixes'
         'libxkbcommon'
         'libxrandr'
         'libxtst'
         'mesa'
         'nspr'
         'nss'
         'pango'
         'socat'
         'systemd-libs'
         'util-linux-libs'
         'virtiofsd'
         'xdg-desktop-portal'
         'xdg-utils')

# Cowork runs its sandbox in a QEMU VM. Upstream lists the VM stack under
# "Recommends:", which apt installs by default, so depend on it here to get the
# same out-of-the-box behaviour.
depends_x86_64=('qemu-system-x86' 'edk2-ovmf')
depends_aarch64=('qemu-system-aarch64' 'edk2-aarch64')

optdepends=('gnome-keyring: credential storage via Secret Service (GNOME)'
            'kwallet: credential storage (KDE Plasma)'
            'libayatana-appindicator: system tray icon'
            'xdg-desktop-portal-gtk: portal backend for GTK desktops'
            'xdg-desktop-portal-hyprland: portal backend for Hyprland'
            'xdg-desktop-portal-kde: portal backend for KDE Plasma')

conflicts=('claude' 'claude-desktop-bin')

# These are prebuilt Electron/Chromium binaries. Stripping them can corrupt
# embedded resources and the V8 snapshot, and saves nothing; !debug turns off
# the companion -debug package, which only makes sense when building from
# source.
options=('!strip' '!debug')

_baseurl="${APT_BASE}/pool/main/c/${PKGNAME}"
source_x86_64=("\${_baseurl}/\${pkgname}_\${pkgver}_amd64.deb")
source_aarch64=("\${_baseurl}/\${pkgname}_\${pkgver}_arm64.deb")
sha256sums_${sums_arch}=('${sha256}')

package() {
  # A .deb is an ar archive, which makepkg unpacks like any other source, so
  # \$srcdir holds debian-binary, control.tar.* (metadata and the maintainer
  # scripts, both unused) and data.tar.* - the file payload, which is the whole
  # package. Upstream currently compresses with xz; glob so a switch to zstd
  # does not break the build.
  local payload=("\$srcdir"/data.tar.*)
  [[ -f "\${payload[0]}" ]] || { echo "no data.tar.* in \$srcdir" >&2; return 1; }

  bsdtar -xf "\${payload[0]}" -C "\$pkgdir"

  # chrome-sandbox is Chromium's setuid sandbox helper: mode 4755 lets it build
  # the sandbox on kernels where unprivileged user namespaces are off. Arch
  # enables those, so this only matters as a fallback (linux-hardened, say), but
  # ship it the way upstream and every other Chromium package does. The payload
  # already carries the mode; setting it states that the setuid bit is intended.
  chmod 4755 "\$pkgdir/usr/lib/${PKGNAME}/chrome-sandbox"

  # lintian is Debian's package linter and has no consumer on Arch.
  rm -rf "\$pkgdir/usr/share/lintian"

  # --- Cowork compatibility shims --------------------------------------------
  # The app hardcodes Debian's paths for the Cowork VM stack; these symlinks
  # point them at where Arch actually puts the pieces.
  #
  # virtiofsd: Debian ships it in /usr/bin, Arch in /usr/lib.
  ln -sf ../lib/virtiofsd "\$pkgdir/usr/bin/virtiofsd"

  # UEFI firmware: on x86_64 the app opens the Debian-named
  # /usr/share/OVMF/OVMF_CODE_4M.fd. On Arch /usr/share/OVMF is a compat symlink
  # to /usr/share/edk2 (owned by edk2-ovmf), so put Debian-named links in
  # /usr/share/edk2 pointing at the real firmware under x64/.
  #
  # aarch64 needs no shim: there the app opens /usr/share/AAVMF/AAVMF_CODE.fd,
  # and edk2-aarch64 already installs it at exactly that path.
  if [[ \$CARCH == x86_64 ]]; then
    install -d "\$pkgdir/usr/share/edk2"
    ln -sf x64/OVMF_CODE.4m.fd "\$pkgdir/usr/share/edk2/OVMF_CODE_4M.fd"
    ln -sf x64/OVMF_VARS.4m.fd "\$pkgdir/usr/share/edk2/OVMF_VARS_4M.fd"
  fi

  # Cowork's host<->VM channel also needs the vhost_vsock module, but nothing
  # configures it: the module declares a devname alias, so its device node
  # exists at boot and the kernel autoloads it on first open.

  # Arch convention: a non-common license goes in /usr/share/licenses/<pkgname>.
  if [[ -f "\$pkgdir/usr/share/doc/${PKGNAME}/copyright" ]]; then
    install -Dm644 "\$pkgdir/usr/share/doc/${PKGNAME}/copyright" \\
      "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
  fi
}
PKGBUILD
}

# --- install -----------------------------------------------------------------

install_package() {
    local want="$1"
    local entry version sha256 current

    info "Reading Anthropic's apt index..."
    entry="$(resolve_entry "$want")"
    IFS=$'\t' read -r version sha256 <<< "$entry"

    current="$(installed_version)"
    if [[ -n "$current" && "$current" == "$version" ]]; then
        info "${PKGNAME} ${version} is already installed. Nothing to do."
        return
    fi

    if [[ -n "$current" ]]; then
        info "Upgrading ${PKGNAME} ${current} -> ${version}"
    else
        info "Installing ${PKGNAME} ${version}"
    fi

    BUILD_DIR="$(mktemp -d "${BUILD_ROOT}/${PKGNAME}.XXXXXX")"
    trap cleanup EXIT

    write_pkgbuild "$BUILD_DIR" "$version" "$sha256"

    # Prime the sudo timestamp only once there is definitely something to build,
    # so a bad --version or an up-to-date install never prompts for a password.
    sudo -v

    info "Downloading the .deb (~170 MB) and building the package..."
    info "makepkg verifies it against the SHA256 published in the apt index."
    ( cd "$BUILD_DIR" && makepkg -si --noconfirm )

    is_installed "$PKGNAME" \
        || die "makepkg finished but ${PKGNAME} is not installed; something went wrong."

    info "Done: $(pacman -Q "$PKGNAME")"
    info "Launch it with 'claude-desktop', or from your application launcher."
}

# --- status ------------------------------------------------------------------

show_status() {
    local current latest entry

    if is_installed "$PKGNAME"; then
        current="$(installed_version)"
        info "installed: ${PKGNAME} ${current}"
    else
        warn "installed: ${PKGNAME} is not installed"
        current=""
    fi

    if ! entry="$(resolve_entry "" 2>/dev/null)"; then
        warn "upstream: could not reach ${APT_BASE}"
        return
    fi

    latest="$(cut -f1 <<< "$entry")"
    info "upstream:  ${latest} (latest in Anthropic's apt index)"

    if [[ -n "$current" ]]; then
        case "$(vercmp "$latest" "$current")" in
            0)  info "up to date." ;;
            -*) warn "installed version is newer than upstream's latest; nothing to do." ;;
            *)  warn "an update is available - re-run this script to build ${latest}." ;;
        esac
    fi

    # A package built here and one installed from the AUR share a name, so
    # pacman reports whichever was installed last without saying where it came
    # from. Point at where to look rather than guessing.
    if is_installed "$PKGNAME"; then
        info "provenance: $(pacman -Qi "$PKGNAME" | sed -n 's/^Packager *: *//p')"
    fi
}

# --- revert ------------------------------------------------------------------

revert_package() {
    if ! is_installed "$PKGNAME"; then
        warn "${PKGNAME} is not installed; nothing to remove."
        return
    fi

    info "Removing ${PKGNAME} and any dependencies it no longer needs..."
    sudo pacman -Rns --noconfirm "$PKGNAME"

    info "Removed. Your chat history and settings are untouched in"
    info "  ${XDG_CONFIG_HOME:-${HOME}/.config}/Claude"
}

# --- entrypoint --------------------------------------------------------------

main() {
    local revert=0 status=0 print_only=0
    local want=""
    local entry version sha256 dir

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -V|--version)
                [[ $# -ge 2 ]] || die "--version needs a version string, e.g. 1.30096.1."
                want="$2"
                shift
                ;;
            -p|--print-pkgbuild) print_only=1 ;;
            -k|--keep-build)     KEEP_BUILD=1 ;;
            -s|--status)         status=1 ;;
            -r|--revert)         revert=1 ;;
            -h|--help)           usage; exit 0 ;;
            *)                   error "Unknown option: $1"; usage >&2; exit 1 ;;
        esac
        shift
    done

    check_environment
    mkdir -p "$BUILD_ROOT"

    if [[ $status -eq 1 ]]; then
        show_status
        exit 0
    fi

    if [[ $revert -eq 1 ]]; then
        revert_package
        exit 0
    fi

    if [[ $print_only -eq 1 ]]; then
        entry="$(resolve_entry "$want")"
        IFS=$'\t' read -r version sha256 <<< "$entry"
        dir="$(mktemp -d)"
        write_pkgbuild "$dir" "$version" "$sha256"
        cat "${dir}/PKGBUILD"
        rm -rf "$dir"
        exit 0
    fi

    install_package "$want"
}
main "$@"
