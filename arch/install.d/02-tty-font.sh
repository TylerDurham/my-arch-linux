on_install() {
  local font="ter-132b"
  grep -q '^FONT=' /etc/vconsole.conf && \
    sudo sed -i "s/^FONT=.*/FONT=$font/" /etc/vconsole.conf || \
    echo "FONT=$font" | sudo tee -a /etc/vconsole.conf > /dev/null

  # The mkinitcpio `consolefont` hook bakes vconsole.conf's FONT into the
  # initramfs at build time, so early boot (e.g. the LUKS prompt) won't
  # pick up the change until the image is rebuilt.
  sudo mkinitcpio -P
}

on_uninstall() {
  local font=default8x16
  grep -q '^FONT=' /etc/vconsole.conf && \
    sudo sed -i "s/^FONT=.*/FONT=$font/" /etc/vconsole.conf || \
    echo "FONT=$font" | sudo tee -a /etc/vconsole.conf > /dev/null

  sudo mkinitcpio -P
}
