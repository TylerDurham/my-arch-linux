local M = {}

local function file_exists(path)
	local f = io.open(path, "r")
	if f then f:close() end
	return f ~= nil
end

-- Requires a top-level hypr-config file (one nwg-displays generates and
-- .gitignore excludes) only if it actually exists on disk, so a fresh
-- checkout that hasn't run nwg-displays yet doesn't crash the whole config.
-- `fallback`, if given, runs instead when the file is missing.
M.require = function(name, fallback)
	local path = os.getenv("HOME") .. "/.config/hypr/" .. name .. ".lua"
	if file_exists(path) then
		require(name)
	elseif fallback then
		fallback()
	end
end

return M
