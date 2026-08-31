-- ~/.config/nvim/lua/config/colorscheme.lua
-------------------------------------------------------------------------------
--- Colorscheme persistence and selection for Neovim.
---
--- Saves the active colorscheme to disk and restores it on startup,
--- so the editor always resumes with the last manually chosen theme.
--- Also provides a Telescope picker for interactive selection.
---
--- State is persisted to a plain-text file in Neovim's data directory:
---   `~/.local/share/nvim/saved_colorscheme.txt`
---
--- Public API:
---   `M.load()`    -- Restore the saved colorscheme on startup
---   `M.save()`    -- Persist the current colorscheme to disk
---   `M.select()`  -- Open a Telescope picker to choose a colorscheme
---
--- Intended to be called from your init.lua or a dedicated plugin spec:
--- @usage
---   local colorscheme = require("config.colorscheme")
---   colorscheme.load()
---
--- @module  colorscheme
--- @license MIT
-------------------------------------------------------------------------------

local M = {}

local state_file = vim.fn.stdpath("data") .. "/saved_colorscheme.txt"
--- Sets custom highlight groups for the Blink completion plugin.
---
--- Configures colours for the documentation popup and completion menu,
--- using a deep navy background palette with accent borders.
---
--- Highlight groups defined:
---   - BlinkCmpDoc            : Documentation popup (bg + fg)
---   - BlinkCmpDocBorder      : Documentation popup border (bold accent)
---   - BlinkCmpMenu           : Completion menu (bg + fg)
---   - BlinkCmpMenuBorder     : Completion menu border
---   - BlinkCmpMenuSelection  : Selected completion item (bold highlight)
---
--- @usage Call once during Neovim startup, e.g. from a `ColorScheme` autocmd
---        to ensure highlights persist after colorscheme changes.
local function set_blink_highlights()
  local h = vim.api.nvim_set_hl
  -- doc popup: deep navy bg with bright border
  h(0, "BlinkCmpDoc",        { bg = "#1e2030", fg = "#c8d3f5" })
  h(0, "BlinkCmpDocBorder",  { fg = "#82aaff", bold = true })
  -- completion menu
  h(0, "BlinkCmpMenu",       { bg = "#1e2030", fg = "#c8d3f5" })
  h(0, "BlinkCmpMenuBorder", { fg = "#3d59a1" })
  h(0, "BlinkCmpMenuSelection", { bg = "#2d3f76", bold = true })
end

function M.current()
  local f = io.open(state_file, "r")
  if f then
    local name = f:read("*l")
    f:close()
    if name and name ~= "" then
      return name
    end
  end

  return "tokyonight-storm"
end

function M.save(name)
  local f = io.open(state_file, "w")
  if f then
    f:write(name)
    f:close()
  end

  M.load()
end

--- Opens a Telescope picker to interactively select a colorscheme.
---
--- Lists all available colorschemes via `vim.fn.getcompletion` and
--- presents them in a fuzzy-searchable Telescope window. Confirming
--- a selection closes the picker and persists the chosen colorscheme
--- by delegating to `M.save`.
---
--- Requires the `nvim-telescope/telescope.nvim` plugin to be loaded.
---
--- @depends M.save  Called with the selected colorscheme name to persist it.
---
--- @usage
---   vim.keymap.set("n", "<leader>cs", M.select, { desc = "Pick colorscheme" })
M.select = function()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "ColorSchemes",
    finder = finders.new_table {
      results = vim.fn.getcompletion("", "color"),
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local colorscheme = selection[1]

        -- your custom logic here
        M.save(colorscheme)
      end)
      return true
    end,
  }):find()
end

--- Loads and applies the persisted colorscheme from disk.
---
--- Reads the saved colorscheme name from `state_file` and applies it.
--- If the file is missing, unreadable, or empty, falls back to the
--- default colorscheme (`tokyonight-storm`).
---
--- In both cases, Blink completion highlights are re-applied afterwards
--- to ensure they survive the colorscheme change.
---
--- @see M.save  For persisting the current colorscheme to `state_file`.
function M.load()
  local f = io.open(state_file, "r")
  if f then
    local name = f:read("*l")
    f:close()
    if name and name ~= "" then
      vim.cmd.colorscheme(name)
      set_blink_highlights()
      return
    end
  end
  -- fallback default
  vim.cmd.colorscheme(M.current())
  set_blink_highlights()
end

-- vim.api.nvim_create_autocmd("ColorScheme", {
--   callback = set_blink_highlights,
-- })
--
-- -- Command to switch and persist
-- vim.api.nvim_create_user_command("MyTheme", function(opts)
--   local name = opts.args
--   vim.cmd.colorscheme(name)
--   M.save(name)
-- end, {
--   nargs = 1,
--   complete = "color",  -- tab-completes installed colorschemes!
-- })

vim.api.nvim_create_user_command("ThemeSelect", function(opts)
  M.select()
end, {})

return M
