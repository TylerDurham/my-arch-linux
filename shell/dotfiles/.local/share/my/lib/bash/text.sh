# print_bitmask_names — Print each flag name in ALL_FLAGS, colorized by
# whether it's set in MASK (green if set, dim if unset).
#
# Args:
#   $1  name of an array variable holding flag-name strings (nameref)
#   $2  integer bitmask to test each flag against
#
# Globals read:
#   Indirectly reads the variable named by each element of $1 (i.e. each
#   flag name must resolve via `${!bit}` to its bit value).
#
# Output:
#   One colorized flag name per line on stdout.
#
# Returns:
#   0 always (no error path; empty _flags array just prints nothing).
#
# Examples:
#   print_bitmask_names ALL_OPTIONS "$OPTIONS"
#   print_bitmask_names ALL_OPTIONS "$((OPT_INSTALL | OPT_VERBOSE))"
#
#   while IFS= read -r opt; do
#       printf '%s\n' "$opt" | indent
#   done < <(print_bitmask_names ALL_OPTIONS "$OPTIONS")
print_bitmask_names() {
    local -n _flags=$1
    local -i mask=$2
    local bit val
    for bit in "${_flags[@]}"; do
        val=${!bit}
        if (( mask & val )); then
            green "${bit}"; echo
        else
            dim "${bit}"; echo
        fi
    done
}

# to_binary — Render an integer as a zero-padded binary string.
#
# Args:
#   $1  integer value to convert (N)
#   $2  output width in bits (default: 8); N is not masked to this width,
#       so a value wider than WIDTH just prints extra leading digits
#
# Output:
#   The binary representation on stdout, newline-terminated, left-padded
#   with zeros to at least WIDTH characters.
#
# Returns:
#   0 always.
#
# Examples:
#   to_binary 5
#   # 00000101
#
#   to_binary 5 4
#   # 0101
#
#   to_binary "$OPTIONS" 7
#   # e.g. 0010110  (one bit per flag, matches ALL_OPTIONS width)
#
#   printf 'mask = %s\n' "$(to_binary "$mask" 16)"
to_binary() {
    local -i n=$1 width=${2:-8}
    local bits=""
    for (( i = width - 1; i >= 0; i-- )); do
        bits+=$(( (n >> i) & 1 ))
    done
    printf '%s\n' "$bits"
}

