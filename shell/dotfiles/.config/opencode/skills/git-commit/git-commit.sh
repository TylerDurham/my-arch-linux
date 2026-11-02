#!/bin/bash
# Git commit with nvim workflow - helper script
# This script handles the nvim review and commit workflow.
# It expects the commit message to already be written to /tmp/opencode/commit-msg.txt
#
# Usage in skill: AI generates message -> writes file -> calls this script
# Or: git-commit.sh "<commit message>" (message passed as argument)

set -e

COMMIT_MSG_FILE="/tmp/opencode/commit-msg.txt"
COMMIT_MSG="${1:-}"

# Create tmp directory if needed
mkdir -p /tmp/opencode

# If message passed as argument, write it to file
if [ -n "$COMMIT_MSG" ]; then
    echo "$COMMIT_MSG" > "$COMMIT_MSG_FILE"
fi

# Check if file exists and has content
if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file does not exist."
    echo "Write the message to $COMMIT_MSG_FILE first, then run this script."
    exit 1
fi

if [ ! -s "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file is empty."
    exit 1
fi

# Open in nvim for review
echo "Opening commit message in nvim for review..."
echo "Edit the message then save and quit (:wq or :x) to commit, or quit without saving (:q!) to abort."
before_mtime=$(stat -c %.9Y "$COMMIT_MSG_FILE")
nvim "$COMMIT_MSG_FILE"
after_mtime=$(stat -c %.9Y "$COMMIT_MSG_FILE")

# Abort if the file wasn't written (e.g. :q!)
if [ "$before_mtime" = "$after_mtime" ]; then
    echo "Commit message not saved. Commit aborted."
    exit 0
fi

# After nvim closes, verify file still has content
if [ ! -s "$COMMIT_MSG_FILE" ]; then
    echo "Commit message file is empty. Commit aborted."
    exit 0
fi

# Validate the commit message format (basic check for conventional commit)
if ! grep -qE '^[a-z]+(\([a-z]+\))?!?: ' "$COMMIT_MSG_FILE"; then
    echo "Warning: Commit message doesn't match conventional commit format."
    read -p "Still commit with this message? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Commit aborted."
        exit 0
    fi
fi

# Commit with the saved message
git commit -F "$COMMIT_MSG_FILE"

echo ""
echo "Committed:"
git log --oneline -1
