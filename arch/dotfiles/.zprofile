  if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    # Only auto-start once per boot: getty@tty1 autologins on every restart
    # (see arch/install.d/11-autologin.sh), so exiting Hyprland would
    # otherwise drop back into a fresh login shell that immediately
    # re-execs it. The marker is keyed by boot ID so it's implicitly reset
    # on every reboot without needing cleanup.
    marker="/tmp/.hyprland-autostarted-$(</proc/sys/kernel/random/boot_id)"
    [[ -e $marker ]] || { touch "$marker" && exec start-hyprland; }
  fi
