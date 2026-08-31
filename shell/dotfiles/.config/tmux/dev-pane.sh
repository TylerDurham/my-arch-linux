#!/usr/bin/env bash
#
# Toggle a dev pane on the right-hand third of the current window.
#
# Hiding parks the pane in a detached "_dev_stash_<session>" session rather than
# killing it, so servers, watchers and log tails survive the toggle. Each window
# gets its own dev pane, keyed by window id — same idea as popup.sh.

set -euo pipefail

STASH_PREFIX="right pane"
DEV_WIDTH="30%"

# Anchor to the pane the binding fired from, passed in as $1 (the binding
# expands #{pane_id}; run-shell does not export TMUX_PANE). Without an explicit
# anchor tmux resolves "current window" from the most recently active session,
# which is the stash session right after a hide.
pane="${1:-$(tmux display-message -p '#{pane_id}')}"
window_id=$(tmux display-message -t "$pane" -p '#{window_id}')
session_name=$(tmux display-message -t "$pane" -p '#{session_name}')
stash_session="${session_name}-${STASH_PREFIX}"
stash_window="dev${window_id#@}"
cwd=$(tmux display-message -t "$pane" -p '#{pane_current_path}')

# Visible dev pane in this window? Hide it.
dev_pane=$(tmux list-panes -t "$window_id" -F '#{pane_id} #{@dev_pane}' \
  | awk '$2 == "1" { print $1; exit }')

if [[ -n "$dev_pane" ]]; then
  if (( $(tmux list-panes -t "$window_id" | wc -l) < 2 )); then
    tmux display-message "dev pane is the only pane — nothing to hide it behind"
    exit 0
  fi
  tmux has-session -t "=$stash_session" 2>/dev/null \
    || tmux new-session -d -s "$stash_session" -n _keep
  tmux break-pane -d -s "$dev_pane" -t "${stash_session}:" -n "$stash_window"
  exit 0
fi

# Stashed dev pane for this window? Bring it back, full height on the right.
if tmux has-session -t "=$stash_session" 2>/dev/null \
  && tmux list-windows -t "=$stash_session" -F '#{window_name}' | grep -qx "$stash_window"; then
  tmux join-pane -h -f -l "$DEV_WIDTH" -s "${stash_session}:${stash_window}" -t "$window_id"
  exit 0
fi

# Nothing to restore — make a fresh one.
new_pane=$(tmux split-window -h -f -l "$DEV_WIDTH" -c "$cwd" -t "$pane" -P -F '#{pane_id}')
tmux set -p -t "$new_pane" @dev_pane 1
