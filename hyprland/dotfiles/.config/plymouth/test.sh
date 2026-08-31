#!/usr/bin/env bash

# ❯ how can I test it?
#
# ● You don't need to reboot. You can test it live in your current session:
#
#   Step 1 — install the files only (skip the initramfs rebuild for now):
  sudo mkdir -p /usr/share/plymouth/themes/ayu-dark
  sudo cp .config/plymouth/themes/ayu-dark/* /usr/share/plymouth/themes/ayu-dark/
  sudo plymouth-set-default-theme ayu-dark

  # Step 2 — run the test loop (in one terminal):
  # Start the daemon attached to your current session
  sudo plymouthd --no-daemon --debug --attach-to-session &

  # Show the splash screen
  sudo plymouth show-splash

  # Wait a moment, then simulate the LUKS prompt
  sleep 3 && sudo plymouth ask-for-password --prompt="Please enter passphrase for disk sda2_crypt"

  # Quit when done
  sleep 5 && sudo plymouth quit

  # You can also send individual commands manually to step through it:
  # sudo plymouth show-splash                          # show loading dots
  # sudo plymouth ask-for-password --prompt="Passphrase:"  # trigger password box
  # sudo plymouth update --status=""                   # simulate a keypress (adds a bullet)
  # sudo plymouth quit

  # Once you're happy with it, rebuild the initramfs so it takes effect at boot:
  # sudo mkinitcpio -P   # Arch
  # # or: sudo dracut --force
  #
  # The key thing: --attach-to-session is what keeps it from hijacking your VT and lets you control it from the same terminal.

