on_install() {
  local font="ter-132b"
  grep -q '^FONT=' /etc/vconsole.conf && \
    sudo sed -i 's/^FONT=.*/FONT=ter-132b/' /etc/vconsole.conf || \
    echo 'FONT=ter-132b' >> /etc/vconsole.conf
}

on_uninstall() {
  local font=default8x16
  grep -q '^FONT=' /etc/vconsole.conf && \
    sudo sed -i 's/^FONT=.*/FONT=default8x16/' /etc/vconsole.conf || \
    echo 'FONT=default8x16' >> /etc/vconsole.conf
}
