#!/usr/bin/env bash
set -euo pipefail

REMOTE_USER="dtd"
REMOTE_HOST="lothlorien.snork.co"
REMOTE_DIR="docker/calibre-web"
REMOTE_LIBRARY="books"
LOCAL_DEST="$HOME/Dropbox/backups/lothlorien.snork.co"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="calibre-books-${TIMESTAMP}.tar.gz"

mkdir -p "$LOCAL_DEST"

echo "Backing up Calibre library from ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DIR}/${REMOTE_LIBRARY}"
echo "Destination: ${LOCAL_DEST}/${ARCHIVE}"
echo ""

ssh "${REMOTE_USER}@${REMOTE_HOST}" \
    "tar -czf - -C ~/${REMOTE_DIR} ${REMOTE_LIBRARY}" \
    > "${LOCAL_DEST}/${ARCHIVE}"

SIZE=$(du -sh "${LOCAL_DEST}/${ARCHIVE}" | cut -f1)
echo "Done. ${ARCHIVE} — ${SIZE}"
