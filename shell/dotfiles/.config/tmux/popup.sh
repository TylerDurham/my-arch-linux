#!/usr/bin/env bash

POPUP_SUFFIX="-popup"

CURRENT_SESSION=$(tmux display-message -p -F "#{session_name}")
POPUP_SESSION="${CURRENT_SESSION}${POPUP_SUFFIX}"

# Already inside a popup session — the toggle just detaches. Test the suffix on
# CURRENT_SESSION, not against POPUP_SESSION: in here POPUP_SESSION would be a
# doubled-up "<session>-popup-popup" and never match.
if [[ "$CURRENT_SESSION" == *"$POPUP_SUFFIX" ]]; then
  tmux detach-client
else
  #  WINDOW_ID=$(tmux display-message -p "#{window_id}" | tr -d '@')
  CWD=$(tmux display-message -p "#{pane_current_path}")
  # if tmux has-session -t "$POPUP_SESSION" 2>/dev/null; then
  # tmux send-keys -t "$POPUP_SESSION" " cd $(printf '%q' "$CWD")" Enter
  # fi
  tmux popup -d "$CWD" -xC -yC -w95% -h95% \
    -b rounded \
    -E "tmux attach -t '$POPUP_SESSION' || tmux new -s '$POPUP_SESSION'" # -s "fg=green,bg=default" \
  # -S "fg=#313244" \
fi
