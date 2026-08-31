
local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function substr_after(after, s)
  local length = string.len(after)

  return string.sub(s, length + 1)
end

M = {
  trim = trim,
  substr_after = substr_after
}

return M
