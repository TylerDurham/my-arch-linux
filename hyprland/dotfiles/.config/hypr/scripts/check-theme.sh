#!/usr/bin/env bash
# This script ensures a wallpaper and theme are active on startup.
# It checks for a symlink (the "currently applied" pointer) and falls
# back to sensible defaults if one isn't set yet.

# Check if the "background" symlink exists (i.e. a wallpaper has been chosen before)
if [[ ! -L ~/.config/my/background ]]; then
  # No wallpaper has ever been set — apply the default one
  echo "No background wallpaper applied. Setting default wallpaper..."
  ~/.local/share/my/bin/hypr-set-wallpaper -i ~/.local/share/my/themes/lovely-day/backgrounds/default.jpg
else
  # A wallpaper is already configured — just start the daemon that displays it
  awww img ~/.config/my/background
fi

# Check if the "theme" symlink exists (i.e. a theme has been chosen before)
if [[ ! -L ~/.config/my/theme ]]; then
  # No theme has ever been set — apply the default theme
  echo "No theme applied. Setting default theme..."
  ~/.local/share/my/bin/hypr-set-current-theme lovely-day
fi
# No symlink to background wallpaper...
if [[ ! -L ~/.config/my/background ]]; then 
  echo "No background wallpaper applied. Setting default wallpaper..."
  ~/.local/share/my/bin/hypr-set-wallpaper -i ~/.local/share/my/themes/lovely-day/backgrounds/default.jpg

else
  # Start the wallpaper server
  awww img ~/.config/my/background
fi

# No symlink to theme
if [[ ! -L ~/.config/my/theme ]]; then 
  echo "No theme applied. Setting default theme..."
  ~/.local/share/my/bin/hypr-set-current-theme lovely-day
fi

