
---@param group string highlight group name
---@param attr "fg" | "bg" | "sp"
---@return string hex color, e.g. "#ff0000"
local function get_color(group, attr)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  local val = hl[attr]
  if not val then return "" end
  return string.format("#%06x", val)
end

local M = {
  get_color = get_color
}

return M
