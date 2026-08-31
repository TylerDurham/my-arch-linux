#!/usr/bin/env bash
# Installs the ayu-dark Plymouth theme and sets it as default.
# Must be run as root (or with sudo).

set -euo pipefail

THEME_NAME="ayu-dark"
THEME_SRC="$(cd "$(dirname "$0")/themes/$THEME_NAME" && pwd)"
THEME_DEST="/usr/share/plymouth/themes/$THEME_NAME"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

echo "Installing $THEME_NAME to $THEME_DEST..."
install -d "$THEME_DEST"
install -m644 "$THEME_SRC/$THEME_NAME.plymouth" "$THEME_DEST/"
install -m644 "$THEME_SRC/$THEME_NAME.script"   "$THEME_DEST/"

echo "Setting default theme to $THEME_NAME..."
plymouth-set-default-theme "$THEME_NAME"

echo "Rebuilding initramfs..."
if command -v mkinitcpio &>/dev/null; then
    mkinitcpio -P
elif command -v dracut &>/dev/null; then
    dracut --force
elif command -v update-initramfs &>/dev/null; then
    update-initramfs -u
else
    echo "WARNING: Could not detect initramfs tool. Rebuild manually."
fi

echo "Done. Reboot to see the theme."
