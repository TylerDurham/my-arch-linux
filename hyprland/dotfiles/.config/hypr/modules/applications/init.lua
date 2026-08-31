-- TODO: Need to add to a global module for reuse
local dir = os.getenv("HOME") .. "/.config/hypr/modules/applications"
local handle = io.popen('ls "' .. dir .. '"/*.lua 2>/dev/null')

if handle then
	for file in handle:lines() do
		local basename = file:match("([^/]+)%.lua$")
		if basename and basename ~= "init" then
			require("modules.applications." .. basename)
		end
	end
	handle:close()
end
