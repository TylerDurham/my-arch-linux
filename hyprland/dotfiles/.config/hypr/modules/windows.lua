
-- Fix some dragging issues with XWayland.
hl.window_rule({
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

hl.window_rule({
  name = "floating-window",
  match = {
    tag = "floating-window"
  },
  float = true,
  center = true,
  size = { 1280, 800 },
  opacity = "1.0"
})

-- Moadal windows - floating windows that must be explicity "closed".
hl.window_rule({
  name = "modal-window",
  match = { tag = "modal-window" },
  confine_pointer = true,
  dim_around = true,
  tag = "+floating-window"
})

hl.window_rule({
  name = "tui-window",
  match = { class = "com.snork.my-terminal" },
  confine_pointer = true,
  dim_around = true,
  tag = "+floating-window"
})

hl.window_rule({
  name = "media-window",
  match = { tag = "media-window" },
  dim_around = true,
  opacity = "1.0",
  workspace = "9"
})

hl.window_rule({
  name = "gtk-window",
  match = { class = "xdg-desktop-portal-gtk" },
  tag = "+floating-window"
})
-- hl.window_rule({
--   name = "multimedia-window",
--   match = {
--     class = "^([s|S]potify|plexamp)$"
--   },
--   workspace = "9",
--   opacity = "1.0 override"
-- })
--
-- hl.window_rule({
--   name = "terminal-window",
--   match = {
--     class = "^(com.mitchellh.ghostty)$"
--   },
--   workspace = "1",
--   opacity = "0.9 override"
-- })
--
--
