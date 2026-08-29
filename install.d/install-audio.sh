#!/usr/bin/env bash
#
# install-audio.sh - install the audio pieces Arch does not pull in by default
#
# Usage:
#   ./install-audio.sh             install rtkit and restart the PipeWire stack
#   ./install-audio.sh -h|--help   show this help
#
# Arch installs PipeWire without rtkit, so PipeWire's data-loop threads never
# get realtime scheduling and audio breaks up under load. rtkit is what lets
# them run at RR priority. The restart is what makes the *running* session pick
# rtkit up, so playback does not stay broken until the next login.

set -euo pipefail

usage() {
    sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

case "${1:-}" in
    -h | --help) usage; exit 0 ;;
    "") ;;
    *) usage >&2; exit 1 ;;
esac

sudo pacman -S --needed rtkit
systemctl --user restart pipewire pipewire-pulse wireplumber
