#!/usr/bin/env bash
set -euo pipefail

sudo pacman -S bolt
sudo systemctl enable --now bolt
boltctl list
