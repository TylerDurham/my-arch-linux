hl.window_rule({
  name = "Plex/Plexamp",
  match = {
    class = "^(tv.plex.Plex|tv.plex.plex-bin|plexamp)$"
  },
  tag = "+media-window"
})
