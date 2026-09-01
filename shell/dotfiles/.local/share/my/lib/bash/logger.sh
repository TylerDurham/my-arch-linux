# =============================================================================
# logging.sh - ANSI color, style, and text-layout helpers for bash scripts.
#
# Source this file, then call the generated helpers by name:
#
#     source lib/logging.sh
#     red "something broke"; echo
#     { bold "Results"; echo; } | indent 2
#
# Every helper writes to stdout WITHOUT a trailing newline, so the caller keeps
# control of line breaks and helpers stay composable inside pipelines and
# command substitution.
#
# Naming: functions are lowercase, data is UPPERCASE. POSIX reserves the all-
# caps namespace for environment variables, so the tables (COLORS, STYLES,
# BG_COLORS, RESET) are caps and every callable is not. Table KEYS stay caps
# because they are constants - COLORS[RED] feeds the helper named `red`.
#
# Requires bash 4+ (associative arrays, `declare -g`, `${var,,}`).
# =============================================================================

[[ -n "${_LOGGER_SH_INCLUDED:-}" ]] && return 0
readonly _LOGGER_SH_INCLUDED=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/require.sh" "err_codes"

# # Glyph drawn at the badge's leading edge, in the accent color. A left half
# # block reads as a solid bar in most fonts; set to "" for no bar.
BADGE_BAR=$'▌'

# COLORS

# Set to a non-empty value to mean "suppress color". Currently declared but
# never consulted: print_color/print_style decide per call by testing whether
# fd 2 is a terminal. Honoring it would make this library respect the
# no-color.org convention (`NO_COLOR=1 ./script`).
NO_COLOR=

# SGR sequence that clears every active color and text attribute. Emitted after
# each colored or styled span so formatting never bleeds into later output.
RESET=$'\033[0m'

# === Text Styles ===
# SGR attribute codes keyed by style name. Consumed by print_style(), and each
# key generates a lowercased wrapper below (bold, dim, italic, underline).
# Support is uneven across terminals - BOLD and UNDERLINE are near-universal,
# DIM and ITALIC are commonly ignored or substituted.
declare -g -A STYLES=(
    [BOLD]=$'\033[1m'
    [DIM]=$'\033[2m'
    [ITALIC]=$'\033[3m'
    [UNDERLINE]=$'\033[4m'
)

# === Regular Colors ===
# Foreground SGR codes keyed by color name: 30-37 for the standard palette,
# 90-97 for the bright variants. Each key generates a lowercased helper below
# (red, bright_cyan, ...). The rendered hue comes from the terminal's theme, so
# treat these as semantic slots rather than exact colors - WHITE on a light
# theme and BLACK on a dark one are both likely invisible.
declare -g -A COLORS=(
    [BLACK]=$'\033[30m'
    [RED]=$'\033[31m'
    [GREEN]=$'\033[32m'
    [YELLOW]=$'\033[33m'
    [BLUE]=$'\033[34m'
    [PURPLE]=$'\033[35m'
    [CYAN]=$'\033[36m'
    [WHITE]=$'\033[37m'
    [BRIGHT_BLACK]=$'\033[90m'
    [BRIGHT_RED]=$'\033[91m'
    [BRIGHT_GREEN]=$'\033[92m'
    [BRIGHT_YELLOW]=$'\033[93m'
    [BRIGHT_BLUE]=$'\033[94m'
    [BRIGHT_PURPLE]=$'\033[95m'
    [BRIGHT_CYAN]=$'\033[96m'
    [BRIGHT_WHITE]=$'\033[97m'
)

# === Background Colors ===
# Background SGR codes mirroring COLORS: 40-47 standard, 100-107 bright.
# Consumed by print_bg_color(); each key generates a bg_-prefixed helper below
# (bg_red, bg_bright_cyan, ...). The prefix is required because these keys
# collide with COLORS - see the generator loops.
#
#     bg_red " ALERT "
#     bg_yellow "$(black " WARN ")"    # black on yellow
declare -g -A BG_COLORS=(
    [BLACK]=$'\033[40m'
    [RED]=$'\033[41m'
    [GREEN]=$'\033[42m'
    [YELLOW]=$'\033[43m'
    [BLUE]=$'\033[44m'
    [PURPLE]=$'\033[45m'
    [CYAN]=$'\033[46m'
    [WHITE]=$'\033[47m'
    [BRIGHT_BLACK]=$'\033[100m'
    [BRIGHT_RED]=$'\033[101m'
    [BRIGHT_GREEN]=$'\033[102m'
    [BRIGHT_YELLOW]=$'\033[103m'
    [BRIGHT_BLUE]=$'\033[104m'
    [BRIGHT_PURPLE]=$'\033[105m'
    [BRIGHT_CYAN]=$'\033[106m'
    [BRIGHT_WHITE]=$'\033[107m'
 )

# # --- catppuccin palette -----------------------------------------------------
#
# # Badges are drawn from the Catppuccin palette rather than the 16 ANSI slots,
# # because the ANSI slots cannot express a surface color - the muted ground that
# # makes a badge read as a raised chip. That requires 24-bit color.
# #
# # Switch flavors with `catppuccin_flavor macchiato` after sourcing, or set
# # CATPPUCCIN_FLAVOR before. Accent-on-surface0 clears WCAG AA in every flavor,
# # including the light one (Latte), where the surfaces darken and the accents
# # lighten in step.
# CATPPUCCIN_FLAVOR="${CATPPUCCIN_FLAVOR:-mocha}"
#
#
# declare -g -A PALETTE=()
#
# # Populate PALETTE for $1 (mocha|macchiato|frappe|latte). Called once at source
# # time; call again to switch. Unknown names leave the palette untouched and
# # return 1.
# catppuccin_flavor() {
#   case "${1,,}" in
#     mocha) PALETTE=(
#       [base]=#1E1E2E   [surface0]=#313244 [surface1]=#45475A [surface2]=#585B70
#       [overlay1]=#7F849C [overlay2]=#9399B2 [subtext1]=#BAC2DE [text]=#CDD6F4
#       [rosewater]=#F5E0DC [flamingo]=#F2CDCD [pink]=#F5C2E7 [mauve]=#CBA6F7
#       [red]=#F38BA8 [maroon]=#EBA0AC [peach]=#FAB387 [yellow]=#F9E2AF
#       [green]=#A6E3A1 [teal]=#94E2D5 [sky]=#89DCEB [sapphire]=#74C7EC
#       [blue]=#89B4FA [lavender]=#B4BEFE ) ;;
#     macchiato) PALETTE=(
#       [base]=#24273A   [surface0]=#363A4F [surface1]=#494D64 [surface2]=#5B6078
#       [overlay1]=#8087A2 [overlay2]=#939AB7 [subtext1]=#B8C0E0 [text]=#CAD3F5
#       [rosewater]=#F4DBD6 [flamingo]=#F0C6C6 [pink]=#F5BDE7 [mauve]=#C6A0F6
#       [red]=#ED8796 [maroon]=#EE99A0 [peach]=#F5A97F [yellow]=#EED49F
#       [green]=#A6DA95 [teal]=#8BD5CA [sky]=#91D7E3 [sapphire]=#7DC4E4
#       [blue]=#8AADF4 [lavender]=#B7BDF8 ) ;;
#     frappe) PALETTE=(
#       [base]=#303446   [surface0]=#414559 [surface1]=#51576D [surface2]=#626880
#       [overlay1]=#838BA7 [overlay2]=#949CBB [subtext1]=#B5BFE2 [text]=#C6D0F5
#       [rosewater]=#F2D5CF [flamingo]=#EEBEBE [pink]=#F4B8E4 [mauve]=#CA9EE6
#       [red]=#E78284 [maroon]=#EA999C [peach]=#EF9F76 [yellow]=#E5C890
#       [green]=#A6D189 [teal]=#81C8BE [sky]=#99D1DB [sapphire]=#85C1DC
#       [blue]=#8CAAEE [lavender]=#BABBF1 ) ;;
#     latte) PALETTE=(
#       [base]=#EFF1F5   [surface0]=#CCD0DA [surface1]=#BCC0CC [surface2]=#ACB0BE
#       [overlay1]=#8C8FA1 [overlay2]=#7C7F93 [subtext1]=#5C5F77 [text]=#4C4F69
#       [rosewater]=#DC8A78 [flamingo]=#DD7878 [pink]=#EA76CB [mauve]=#8839EF
#       [red]=#D20F39 [maroon]=#E64553 [peach]=#FE640B [yellow]=#DF8E1D
#       [green]=#40A02B [teal]=#179299 [sky]=#04A5E5 [sapphire]=#209FB5
#       [blue]=#1E66F5 [lavender]=#7287FD ) ;;
#     *) return 1 ;;
#   esac
#   CATPPUCCIN_FLAVOR="${1,,}"
# }
# catppuccin_flavor "$CATPPUCCIN_FLAVOR" || catppuccin_flavor mocha
#
# # Nearest ANSI background for each accent, used when the terminal cannot do
# # 24-bit color. Coarse by necessity - several accents collapse onto one slot.
# declare -g -A ACCENT_ANSI=(
#   [rosewater]=WHITE [flamingo]=RED    [pink]=PURPLE  [mauve]=PURPLE
#   [red]=RED         [maroon]=RED      [peach]=YELLOW [yellow]=YELLOW
#   [green]=GREEN     [teal]=CYAN       [sky]=CYAN     [sapphire]=CYAN
#   [blue]=BLUE       [lavender]=BLUE   [overlay1]=BRIGHT_BLACK
#   [overlay2]=BRIGHT_BLACK             [subtext1]=WHITE
# )

# True when the terminal advertises 24-bit color. Inside tmux this also needs
# `set -ga terminal-overrides ",*:RGB"`, or the escapes are swallowed.
_has_truecolor() {
  [[ ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit ]]
}

# Emit an SGR sequence setting layer $1 (38 foreground, 48 background) to the
# #RRGGBB color in $2. printf parses the 0x-prefixed byte slices as numbers.
_rgb() {
  local h="$2"
  printf '\033[%s;2;%d;%d;%dm' "$1" "0x${h:1:2}" "0x${h:3:2}" "0x${h:5:2}"
}

# --- core -------------------------------------------------------------------

# Shared implementation behind print_color, print_bg_color and print_style.
# Private - call one of those instead, so the caller names an attribute rather
# than hand-rolling an escape sequence.
#
#   $1    the opening SGR sequence to apply
#   $2..  the text - all remaining arguments are joined with spaces
#
# Escapes are emitted only when fd 2 is a terminal, so redirected output stays
# plain. Note the asymmetry: the test looks at stderr while the text goes to
# stdout. In a pipeline such as `red msg | indent 2` stderr is still a tty, so
# color survives the pipe - usually the intent here - but `red msg > file`
# also still writes escapes, since fd 2 remains a tty. Test `-t 1` instead if
# you want the check to track where the text is actually going.
#
# Nesting works in any direction and to any depth, across all three tables:
#
#   bold "$(red err) tail"        -> "err" bold+red, " tail" still bold
#   bg_red "$(white crit) rest"   -> "crit" white-on-red, " rest" on red
#
# A stack of active attributes cannot implement this, because the inner command
# substitution runs first, in a subshell, before the outer helper is ever
# invoked - so the outer helper repairs the string it receives instead,
# re-opening itself after every reset the inner span emitted. Each level
# applies this as the string bubbles outward, which rebuilds the whole ancestor
# chain. Interior reset/re-open pairs are load-bearing and remain; a re-open
# that would land at the very end is trimmed.
_print_sgr() {
  local open="$1"
  local reset="$RESET"
  local text="${*:2}"

  # No colors on terminals that don't support
  #[[ ! -t 2 ]] && { open=""; reset=""; }

  # Nested helpers close with RESET, which would clear this span too. Re-open
  # ourselves after each one so our attribute survives past the inner span. The
  # pattern is quoted to keep bash from parsing "[0m" as a bracket expression.
  text="${text//"$RESET"/$RESET$open}"

  # A re-open landing at the very end has nothing left to apply to - the RESET
  # printf appends below closes the span immediately after it. Drop that whole
  # trailing RESET+re-open pair and let the closing RESET do the job. Guarded
  # on open so the disabled-color path never eats a RESET the caller embedded.
  [[ -n "$open" ]] && text="${text%"$RESET$open"}"

  printf '%s%s%s' "$open" "$text" "$reset"
}

# --- public entry points ----------------------------------------------------
#
# Each takes an attribute name from its table plus the text, and writes to
# stdout with no trailing newline. Names are the UPPERCASE table keys. Under
# `set -u` an unrecognized name aborts the script ("COLORS[$1]: unbound
# variable") rather than degrading to plain text - the array lookup happens
# before _print_sgr is ever reached.
#
#   print_color    RED   "disk full:" "$path"     # foreground
#   print_bg_color RED   " ALERT "                # background
#   print_style    BOLD  "Summary"                # text attribute

print_color()    { _print_sgr "${COLORS[$1]}"    "${@:2}"; }
print_bg_color() { _print_sgr "${BG_COLORS[$1]}" "${@:2}"; }
print_style()    { _print_sgr "${STYLES[$1]}"    "${@:2}"; }

# --- generated helpers ------------------------------------------------------

# Generate one wrapper per attribute name, so `red "text"` is shorthand for
# `print_color RED "text"`. eval is required because bash cannot define a
# function whose name comes from a variable; "$key" is expanded at definition
# time and baked into each body, while "\$@" is escaped so it resolves at call
# time. "${key,,}" lowercases the function name while the baked-in table
# lookup keeps the original caps. Leaves `key` set in the sourcing shell.
#
# Background helpers carry a bg_ prefix because their table shares every key
# name with COLORS - without it, BG_COLORS would silently clobber red, green
# and the rest. So: red / bright_cyan are foreground, bg_red / bg_bright_cyan
# are background, bold / italic and friends are styles.
for key in "${!COLORS[@]}"; do
   eval "${key,,}() { print_color \"$key\" \"\$@\"; }"
done

for key in "${!BG_COLORS[@]}"; do
   eval "bg_${key,,}() { print_bg_color \"$key\" \"\$@\"; }"
done

for key in "${!STYLES[@]}"; do
   eval "${key,,}() { print_style \"$key\" \"\$@\"; }"
done

# --- layout -----------------------------------------------------------------

# Prefix every line read on stdin with $1 spaces (default 4). Filter - meant to
# sit on the right-hand side of a pipe.
#
#   { green "ok"; echo; } | indent 2
#
# The width is a count of SPACES, not tabs. Padding is inserted ahead of any
# color escape on the line, so colors come through intact. Because sed is
# line-oriented it only sees complete lines: piping a helper directly
# (`green ok | indent 2`) works, but the caller still supplies the newline.
indent() { sed "s/^/$(printf '%*s' "${1:-4}" '')/" >&2; }

# Right-align $2 in a field of $1 display columns, padding with leading spaces.
# No trailing newline. A string wider than the field is printed in full and
# overflows rather than being truncated.
#
#   pad_left 8 "42"    ->  "      42"
#
# Width is measured with _display_width, so a colored or accented string pads
# to what it LOOKS like, not what it weighs:
#
#   pad_left 10 "$(blue "[INFO]")"   -> 4 spaces + a 6-column label
#
# printf '%*s' cannot do this on its own - it pads by BYTES, so a 6-column
# label carrying 19 bytes of SGR escapes already exceeds a width of 10 and
# comes back unpadded. Compute the shortfall in columns and emit it directly.
pad_left() {
    local width=$1
    local str=$2
    _display_width "$str"
    local fill=$(( width - _WIDTH ))
    if (( fill < 0 )); then fill=0; fi
    printf '%*s%s' "$fill" '' "$str"
}

# Left-align $2 in a field of $1 display columns, padding with trailing spaces.
# Same overflow behavior and column measurement as pad_left. No trailing
# newline.
#
#   pad_right 8 "name"            ->  "name    "
#   pad_right 8 "$(red "name")"   ->  "name    " in red, still 8 columns
pad_right() {
    local width=$1
    local str=$2
    _display_width "$str"
    local fill=$(( width - _WIDTH ))
    if (( fill < 0 )); then fill=0; fi
    printf '%s%*s' "$str" "$fill" ''
}

# --- higher-order formatters ------------------------------------------------

# Horizontal padding, in spaces, added inside fmt_badge and fmt_block on each
# side of the content. Set to 0 for tight output.
BLOCK_PAD=1

# Foreground chosen automatically for a given background.
#
# THERE IS NO PALETTE-INDEPENDENT ANSWER HERE. These names are slots, not
# colors: the terminal theme decides what "red" and "white" actually render as,
# and the right foreground flips with it. This table is tuned for Catppuccin
# (Mocha/Macchiato/Frappe), where every chromatic slot is a pastel - a LIGHT
# ground - and both foregrounds are muted rather than pure:
#
#   fg BLACK = #45475A (surface1)      fg WHITE = #BAC2DE (subtext1)
#
#   background   hex        black fg   white fg
#   RED          #F38BA8       3.94       1.31
#   BLUE         #89B4FA       4.33       1.19
#   GREEN        #A6E3A1       6.14       1.19
#   YELLOW       #F9E2AF       7.18       1.39
#   PURPLE       #F5C2E7       5.97       1.16
#   CYAN         #94E2D5       6.12       1.19
#   BLACK        #45475A       1.00       5.15
#   BRIGHT_BLACK #585B70       1.37       3.77
#
# (WCAG 2.x ratios, Mocha.) White text sits at 1.16-1.39 on every pastel, which
# is illegible - hence BLACK everywhere except the two grey grounds. Note that
# Catppuccin gives the bright chromatic slots the SAME hex as their normal
# counterparts, so BRIGHT_RED and RED are one color in practice.
#
# The stock xterm palette inverts much of this: there RED is #cd0000 and BLUE
# is #0000ee, both dark, and white wins by a wide margin. Catppuccin Latte (the
# light flavor) is different again - RED, BLUE and CYAN there want WHITE.
#
# So: retheme the terminal and this table needs revisiting. It is a plain
# associative array, so a caller can reassign entries after sourcing, and an
# explicit foreground argument to fmt_block always overrides it.
#
# SCOPE: this table drives fmt_block, and fmt_badge only on the non-truecolor
# fallback path. A truecolor badge ignores it entirely - it draws accent text
# on a surface ground from PALETTE, which does not need a contrast heuristic
# because the pairing is fixed and measured. See fmt_badge.
declare -g -A FG_ON=(
    [BLACK]=WHITE     [BRIGHT_BLACK]=WHITE
    [RED]=BLACK       [BRIGHT_RED]=BLACK
    [BLUE]=BLACK      [BRIGHT_BLUE]=BLACK
    [PURPLE]=BLACK    [BRIGHT_PURPLE]=BLACK
    [GREEN]=BLACK     [BRIGHT_GREEN]=BLACK
    [YELLOW]=BLACK    [BRIGHT_YELLOW]=BLACK
    [CYAN]=BLACK      [BRIGHT_CYAN]=BLACK
    [WHITE]=BLACK     [BRIGHT_WHITE]=BLACK
)

# Strip every SGR sequence from $1, leaving the visible text in _STRIPPED.
#
# Results come back in a global rather than on stdout because command
# substitution forks a subshell, and these run once per line of every block.
#
# The loop exists because a glob cannot do this safely: bash's `*` is greedy,
# so "${s//$'\033['*m/}" on a string with two escapes matches from the first
# ESC[ through the LAST m and deletes the text between them - it reduces
# "\033[31mred\033[0m" to "". Consuming one escape per pass avoids that: cut at
# the first ESC[, then drop the shortest run up to its terminating m.
_strip_sgr() {
  local s="$1" pre rest
  while [[ $s == *$'\033['* ]]; do
    pre="${s%%$'\033['*}"
    rest="${s#*$'\033['}"
    rest="${rest#*m}"
    s="$pre$rest"
  done
  _STRIPPED="$s"
}

# Display width of $1 in terminal columns, ignoring SGR sequences, into _WIDTH.
#
# None of bash's built-in length operators answer this on their own:
#
#   string          ${#s}   bytes   columns
#   "abcd"            4       4        4
#   "cafe'"           4       5        4     <- printf '%*s' pads by bytes
#   "<2 CJK chars>"   2       6        4     <- and ${#} undercounts by half
#
# So ${#s} is right for ASCII and wrong for anything wide, while `wc -L` is
# right for everything but costs a fork (~0.85ms, measured ~55x the builtin).
# Take the builtin whenever the text is pure ASCII, which is the common case,
# and pay for wc only when a multibyte character is actually present. If wc -L
# is unavailable (it is a GNU extension), fall back to the character count -
# too narrow for CJK, but never wrong for Latin text.
_display_width() {
  _strip_sgr "$1"
  local s="$_STRIPPED"

  if [[ $s == *[![:ascii:]]* ]]; then
    _WIDTH=$(printf '%s' "$s" | wc -L 2>/dev/null) || _WIDTH=""
    [[ -n $_WIDTH ]] || _WIDTH=${#s}
  else
    _WIDTH=${#s}
  fi
}

# Resolve the background/foreground pair used by fmt_block, and
# leave the combined opening sequence in _OPEN. Consumes $1 (background) and,
# when the caller supplied one, $2 (foreground); sets _SHIFT to how many
# arguments were used so the caller can shift past them.
#
# A foreground is taken from $2 only when it names a COLORS key AND at least
# one argument follows it - otherwise `fmt_badge RED WHITE` would render an
# empty badge instead of the word "WHITE" on red.
_resolve_ground() {
  local bg="${1-}"
  local open=""

  # Both guards below exist because an EMPTY subscript is a hard error on a
  # bash associative array - "COLORS: bad array subscript" - not an empty
  # lookup. Without them an empty background name, or an empty first line of
  # text, crashes here instead of being reported.
  if [[ -n $bg ]]; then open="${BG_COLORS[$bg]}"; fi   # aborts under set -u if unknown
  if [[ -z $open ]]; then
    printf 'logging.sh: unknown background: %s\n' "${bg:-(empty)}" >&2
    return 1
  fi

  local fg
  if (( $# >= 3 )) && [[ -n ${2-} ]] && [[ -n ${COLORS[$2]+x} ]]; then
    fg="$2"; _SHIFT=2
  else
    fg="${FG_ON[$bg]}"; _SHIFT=1
  fi

  _OPEN="$open${COLORS[$fg]}"
}

# Inline badge: a bar and a label on a muted ground, for sitting next to other
# text. No trailing newline, like the rest of the library.
#
#   $1    accent name, a PALETTE key (red, blue, peach, overlay2, ...)
#   $..   the label - remaining arguments are joined with spaces
#
#   fmt_badge red ERROR; echo " disk full"
#
#     [bar][ ERROR ][ disk full]
#      ^ accent      ^ plain text after the badge closes
#      ^^^^^^^^^^^^^ surface0 ground, accent text throughout
#
# The ground is surface0 and both the bar and the label take the accent, which
# is the inverse of an accent-ground badge and measurably more legible: on
# Mocha, red text on surface0 is 5.43:1 where surface1 on a red ground is
# 3.94:1. Every accent clears WCAG AA against surface0 in every flavor.
#
# Falls back to the old ANSI treatment - accent as the GROUND, auto-contrast
# text - when the terminal cannot do 24-bit color, so this stays usable on a
# plain xterm. The fallback is coarse: see ACCENT_ANSI.
#
# BLOCK_PAD spaces are added on each side of the label. Nested helpers work
# normally - the badge re-opens its own ground after them, via _print_sgr.
fmt_badge() {
  local accent_color="${COLORS[$1]}"; shift
  local bg_color="${COLORS[BLACK]}"
  local pad; printf -v pad '%*s' "$BLOCK_PAD" ''

  # if _has_truecolor; then
    local open
    open="$bg_color$accent_color"
    _print_sgr "$open" "$BADGE_BAR$pad$(bold $*)$pad"
  # else
    # _resolve_ground "${ACCENT_ANSI[$accent]}" || return 1
    # _print_sgr "$_OPEN" "$pad$*$pad"
  # fi
}

# Multi-line block: a solid rectangle of colored ground with text inside. Every
# line is padded to the width of the widest one, so the ground stays flush.
#
#   $1    background name, a BG_COLORS key
#   $2    optional foreground name, a COLORS key (see _resolve_ground)
#   $..   one argument per line; with no text arguments, lines are read
#         from stdin instead, which makes this usable as a filter
#
#   fmt_block RED "Deploy failed" "check /var/log/deploy.log"
#   printf '%s\n' one two | fmt_block BLUE
#   fmt_block GREEN "ok" | indent 4
#
# UNLIKE every other helper here, this one DOES emit a trailing newline - one
# after each line. A block is inherently line-oriented, and a ground that spans
# a newline paints to the terminal's right edge on many terminals, so each line
# opens and closes its own ground.
#
# Width is measured with _display_width, so nested colors and accented text do
# not skew the rectangle; see its notes for the CJK caveat.
fmt_block() {
  _resolve_ground "$@" || return 1
  shift "$_SHIFT"

  local -a lines=()
  if (( $# )); then
    lines=("$@")
  else
    mapfile -t lines
  fi
  (( ${#lines[@]} )) || return 0

  local pad; printf -v pad '%*s' "$BLOCK_PAD" ''

  # First pass: widest visible line. Second pass: emit, padded to match.
  local line max=0
  for line in "${lines[@]}"; do
    _display_width "$line"
    if (( _WIDTH > max )); then max=$_WIDTH; fi
  done

  local fill
  for line in "${lines[@]}"; do
    _display_width "$line"
    printf -v fill '%*s' $(( max - _WIDTH )) ''
    _print_sgr "$_OPEN" "$pad$line$fill$pad"
    printf '\n'
  done
}

# --- log levels -------------------------------------------------------------
#
# Two families over the same levels. The plain form prefixes a bracketed label,
# the _badge form prefixes a colored chip built with fmt_badge:
#
#   error "disk full"        ->  [ERROR] disk full
#   error_badge "disk full"  ->   ERROR  disk full      (black on red)
#
# The message is the trailing arguments, joined with spaces.
#
# All of these write to STDERR, which is also the stream _print_sgr tests for a
# terminal - so `error msg 2>log` puts plain text in the file while a terminal
# still gets color. That alignment holds only for this family; the lower-level
# helpers write to stdout while still testing fd 2.
#
# Labels are not padded to a common width, so they sit ragged against each
# other ([INFO] is 6 columns, [WARNING] is 9). Wrap a label in `pad_right 10`
# if you want the messages to line up in a column.
#
# Only debug is gated on LOG_LEVEL - everything from info up always prints, on
# the grounds that a script that bothered to call warn or error wants it seen.
# shared.envs.sh exports LOG_LEVEL=4 (INFO) and the LOG_LEVEL_* constants for
# every session, so raise it per-invocation or per-script:
#
#   LOG_LEVEL=8 ./myscript          # or: LOG_LEVEL=$LOG_LEVEL_DEBUG

# Report an error the caller can recover from. Does not exit - use fatal for
# that.
#
#   $@    the message
#
#   error "connection refused:" "$host"   ->  [ERROR] connection refused: db1
error() {
  local label="$(bold $(red '[ERROR]'))"
  echo "$label ${@}" >&2 
}

# Badge form of error: an " ERROR " chip on red instead of a bracketed label.
#
#   $@    the message
error_badge() {
  fmt_badge red "ERROR" >&2; echo " $@" >&2;
}

# Report normal progress.
#
#   $@    the message
#
#   info "listening on" ":8080"   ->  [INFO] listening on :8080
info() {
  local label="$(bold $(blue '[INFO]'))"
  echo "$label ${@}" >&2
}

# Badge form of info: an " INFO " chip on blue.
#
#   $@    the message
info_badge() {
  fmt_badge BLUE "INFO" >&2; echo " $@" >&2;
}

# Report something suspicious that did not stop the run.
#
#   $@    the message
#
#   warn "retrying in" "5s"   ->  [WARNING] retrying in 5s
warn() {
  local label="$(bold $(yellow '[WARNING]'))"
  echo "$label ${@}" >&2
}

# Badge form of warn: a " WARNING " chip on yellow.
#
#   $@    the message
warn_badge() {
  fmt_badge yellow "WARNING" >&2; echo " $@" >&2;
}

# True when LOG_LEVEL admits debug output. Private - the debug helpers call it.
#
# LOG_LEVEL is read at CALL time, not source time, so a script can raise it
# after sourcing and later debug calls pick that up. An unset or non-numeric
# value falls back to LOG_LEVEL_INFO, which keeps a stray `LOG_LEVEL=verbose`
# from aborting an arithmetic comparison under `set -e`.
_debug_enabled() {
  local level="${LOG_LEVEL:-${LOG_LEVEL_INFO:-4}}"
  [[ "$level" =~ ^[0-9]+$ ]] || level="${LOG_LEVEL_INFO:-4}"
  (( level >= ${LOG_LEVEL_DEBUG:-8} ))
}

# Report detail useful only when diagnosing. Silent unless LOG_LEVEL is at
# least 8 (LOG_LEVEL_DEBUG); see _debug_enabled.
#
#   $@    the message
#
#   LOG_LEVEL=8 ./myscript   ->  [DEBUG] resolved path: /etc/my.conf
debug() {
  _debug_enabled || return 0
  local label="$(bold $(bright_black '[DEBUG]'))"
  echo "$label ${@}" >&2
}

# Badge form of debug: a " DEBUG " chip on overlay2. Gated the same way.
#
#   $@    the message
debug_badge() {
  _debug_enabled || return 0
  fmt_badge PURPLE "DEBUG" >&2; echo " $@" >&2;
}

# Report an unrecoverable error and TERMINATE THE SCRIPT.
#
#   $1    exit status - required, and must be numeric
#   $2..  the message
#
#   fatal 2 "config not found:" "$path"
#
# Unlike every other helper here, this one does not return. Two consequences
# worth keeping in mind:
#
#   - It exits the current shell, so inside a subshell or `$(...)` it kills
#     only that subshell and the script carries on.
#   - The status is mandatory. `fatal "message"` under `set -u` aborts on the
#     unbound $1, and a non-numeric first argument makes bash exit 2 with
#     "numeric argument required" - so the code you get is not the one you
#     meant. Always pass a number first.
#
# The label carries a Nerd Font glyph (U+EA87) ahead of [FATAL]; terminals
# without a patched font render it as a replacement box.
fatal() {
  echo "$(bold $(red ' [FATAL]')) ${*:2}: ${BASH_SOURCE[1]} Line $LINENO" >&2
  exit ${1}
}

# Badge form of fatal: a glyph + " FATAL " chip on red, then exit.
#
#   $1    exit status - required, and must be numeric (see fatal)
#   $2..  the message
#
# Carries the same Nerd Font glyph as fatal.
fatal_badge() {
  fmt_badge maroon " FATAL" >&2; echo " ${*:2}" >&2;
  exit ${1}
}

# package_badge <install|remove> <package...>
# Prints a colored badge with an install/remove icon followed by the package list.
# Globals: none
# Arguments:
#   $1 - action ("install" or anything else, treated as "remove")
#   $@ (after shift) - package name(s) to display
# Outputs:
#   Writes formatted badge line to stdout via fmt_badge
# Returns:
#   0
package_badge() {
  local action="$1"; local name="$2"; shift;
  local icon
  if [[ "$action" == "install" ]]; then
      icon="󱧕"
  else
      icon=="󱧙"
  fi

  shift; fmt_badge GREEN "$icon PKG ${name^^}"; echo "$*"
}

# module_badge <install|remove> <package...>
# Prints a colored badge with an install/remove icon followed by the package list.
# Globals: none
# Arguments:
#   $1 - action ("install" or anything else, treated as "remove")
#   $@ (after shift) - package name(s) to display
# Outputs:
#   Writes formatted badge line to stdout via fmt_badge
# Returns:
#   0

module_badge() {
  local action="$1"; local name="$2"; shift;
  local icon
  if [[ "$action" == "install" ]]; then
      icon=""
  else
      icon=="󰉘"
  fi

  shift; fmt_badge BLUE "$icon MOD ${name^^}"; echo "$*"
}
success() {
  local label="$(bold $(green '[OK]'))"
  echo "$label ${@}" >&2
}

ok() { success "${@}"; }
