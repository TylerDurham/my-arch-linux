hl.config({ general = { layout = "scrolling" } })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
  dwindle = {
    preserve_split = true, -- You probably want this
  },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
  master = {
    new_status = "master",
  },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
  scrolling = {
    fullscreen_on_one_column = true,
    column_width = 1.0,
    explicit_column_widths = "0.8",
    follow_min_visible = false
  },
})

----------------------------------
---- LAYOUT SWITCHING ------------
----------------------------------

local M = {}

-- Layouts to cycle through, in order. Keep the first entry in sync with the
-- initial `general.layout` set at the top of this file.
M.layouts = { "scrolling", "dwindle", "master" }

-- Index of the currently active layout.
local current = 1

-- Apply a layout by name and let the user know which one is now active.
-- Uses the Lua API directly: `hyprctl keyword` is disabled under the non-legacy
-- (Lua) config parser, so we set the value via hl.config and toast via hl.notification.
local function apply(name)
  hl.config({ general = { layout = name } })
  hl.notification.create({ text = "Layout: " .. name, timeout = 1500 })
end

--- Cycle to the next layout in M.layouts and apply it live.
function M.cycle()
  current = (current % #M.layouts) + 1
  apply(M.layouts[current])
end

--- Switch directly to a named layout (e.g. "dwindle").
function M.set(name)
  for i, l in ipairs(M.layouts) do
    if l == name then current = i end
  end
  apply(name)
end

return M

