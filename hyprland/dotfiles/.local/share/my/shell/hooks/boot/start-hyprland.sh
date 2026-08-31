if [[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]]; then
  sleep 5
  echo "Starting Hyprland!"
  start-hyprland
fi
