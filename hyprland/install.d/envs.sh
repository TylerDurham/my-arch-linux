PREFIX=my
PROJECT_ROOT_DIR=$(git rev-parse --show-toplevel)
MY_INSTALL_DIR=$(git rev-parse --show-toplevel)

init() {
  # Libs
  if ! . "$MY_LIB_DIR/bash/require.sh" logger; then
    echo "Could not load libraries from '$MY_LIB_DIR'!" >&2
    exit 1
  fi

  # Where is this file located at?
  CWD=$(dirname $(realpath $0))

  # Parse args and flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -r | --revert)
      REVERT=1
      shift
      ;;
    esac
  done
}

export MY_THEME_DIR="$PROJECT_ROOT_DIR/dotfiles/.local/share/$PREFIX/themes"
export MY_CURRENT_THEME_DIR="$MY_CONFIG_DIR/current"
export PATH="$MY_BIN_DIR:$PATH"
