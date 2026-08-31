
source "$MY_INSTALL_DIR/shell/shared.aliases.sh"

mrequire() {
  local module guard file
  for module in "$@"; do
    if [[ "$module" == /* || "$module" == ./* ]]; then
      file="$module"
      guard="_LOADED_${module//\//_}"; guard="${guard//./_}"
    else
      guard="_LOADED_${module//\//_}"; guard="${guard//./_}"
      file="$MY_BASH_LIB_DIR/${module}.sh"
    fi

    [[ -n "${!guard:-}" ]] && continue
    [[ -f "$file" ]] || { echo "module not found: $file" >&2; return 1; }
    source "$file"
    printf -v "$guard" 1
  done
}

