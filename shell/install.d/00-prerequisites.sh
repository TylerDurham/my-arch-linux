# Read the package list, skipping blank lines and '#' comments.
read_package_list() {
  local pkg_file="$1"
  [[ -f "$pkg_file" ]] ||
    fatal 2 "Package list not found: ${pkg_file}"

  local packages=()

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                      # strip trailing comments
    line="${line#"${line%%[![:space:]]*}"}" # trim leading whitespace
    line="${line%"${line##*[![:space:]]}"}" # trim trailing whitespace
    [[ -n "$line" ]] && echo "$line"
  done <"$pkg_file"
}

on_install() {
  local os=$(sys-get-os)
  local pkg_file="$SEARCH_PATH/${os}-packages.txt"

  mapfile -t packages < <(read_package_list "$pkg_file")
  case "$os" in 
    arch) sudo pacman -Sy --needed --noconfirm "${packages[@]}" ;;
  esac
}

on_uninstall() {
  os=$(sys-get-os)

  if [[ "$os" == "arch" ]]; then
    sudo pacman -Ry --noconfirm "${arch_packages[@]}"
  fi
}
