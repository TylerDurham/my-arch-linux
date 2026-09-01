# Shared environment sourced by each package's ./install script (e.g.
# shell/install) before it pulls in the installer/logger libs. Meant to be
# sourced, not executed directly - it exports the globals every install
# script and module hook relies on.

# Every stow package in the repo, each shaped like:
#   <package>/dotfiles/.local/share/my/bin
#   <package>/install.d/*.sh
export PACKAGES=(
  arch
  hyprland
  shell
  neovim
)

# Repo root, resolved via git so it works no matter which directory the
# caller was invoked from.
export PROJECT_ROOT=$(git rev-parse --show-toplevel)

# Directory of the script that sourced this file (BASH_SOURCE[1], one frame
# up the call stack - BASH_SOURCE[0] would just point at envs.sh itself).
# Currently unused below but kept for callers that need "where am I".
declare -r PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

# installer.sh/logger.sh and friends live here; install scripts source them
# via "$MY_LIB_DIR/bash/<lib>.sh".
export MY_LIB_DIR="$PROJECT_ROOT/shell/dotfiles/.local/share/my/lib"

# Put every package's bin/ on PATH so tools like sys-list-items and
# sys-select-items (used by installer.sh) resolve regardless of which
# package installed them.
for package in "${PACKAGES[@]}"; do
  export PATH="$PROJECT_ROOT/$package/dotfiles/.local/share/my/bin:$PATH"
done
