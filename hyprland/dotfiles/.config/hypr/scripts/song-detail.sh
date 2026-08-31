#!/usr/bin/env bash
# Prints the currently playing song (for use in a status bar, e.g. Waybar).
# Outputs "Artist  |  Title", falls back gracefully if info is missing,
# and prints nothing if there's no player or nothing playing.

# Make sure playerctl is installed before trying to use it
if command -v playerctl &> /dev/null; then
    # Check if a media player is actually active right now
    if playerctl status &> /dev/null; then
        # Pull the artist and title metadata (suppress errors if a field is missing)
        artist=$(playerctl metadata artist 2>/dev/null)
        title=$(playerctl metadata title 2>/dev/null)

        # Prefer "Artist | Title", but degrade gracefully depending on what's available
        if [[ -n "$artist" && -n "$title" ]]; then
            echo "$artist  |  $title"
        elif [[ -n "$title" ]]; then
            echo "$title"
        else
            echo "Music Playing"
        fi
    else
        # playerctl exists but no player is running — print nothing
        echo ""
    fi
else
    # playerctl isn't installed — print nothing
    echo ""
fi
