
hl.window_rule({
  name = "modal-utility-window",
  match = {
    class = "^(.blueman-manager-wrapped|blueman-manager|nm-connection-editor|org.pulseaudio.pavucontrol|org.gnome.Calculator)$"
  },
  tag = "+modal-window",
})
