-- ###################################################################
--
-- ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗ ███████╗
-- ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝
-- ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝███████╗
-- ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗╚════██║
-- ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║███████║
-- ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
-- ###################################################################

local str = require("modules.lib.strings")

local M = {}

M.config = {
	right = {
		output = "desc:BNQ BenQ RD280UG EMF6T00620087",
		mode = "3840x2560@120.0",
		position = "1924x0",
		scale = 2,
	},
	left = {
		output = "desc:Dell Inc. DELL S2725QS 7DCMT84",
		mode = "2560x1440@120.0",
		position = "0x0",
		scale = 1.33,
	},
	builtin = {
		name = "eDP-1",
		scale = 1,
	},
}

M.get_ref_by_desc = function(desc)
	local description = str.trim(str.substr_after("desc:", desc))
	for _, monitor in ipairs(hl.get_monitors()) do
		if monitor.description == description then
			return monitor
		end
	end
	return nil
end

M.get_ref = function(monitor)
	return M.get_ref_by_desc(monitor.output)
end

M.right = function()
	return M.get_ref(M.config.right)
end

M.left = function()
	return M.get_ref(M.config.left)
end

M.builtin = function()
	for _, monitor in ipairs(hl.get_monitors()) do
		if string.sub(monitor.name, 1, 3) == "eDP" then
			return monitor
		end
	end
	return nil
end

if M.config ~= nil then
	if M.config.right ~= nil then
		hl.monitor(M.config.right)
	end
	if M.config.left ~= nil then
		hl.monitor(M.config.left)
	end
end

-- The built-in panel's output name varies by machine (eDP-1, eDP-2, ...), so
-- resolve it at load time from the live monitor list rather than hardcoding it.
-- This only works while the panel is active; that's the normal case at startup.
do
	local b = M.builtin()
	if b ~= nil then
		M.config.builtin.name = b.name
	end
end

M.disable_builtin = function()
	hl.monitor({ output = M.config.builtin.name, disabled = true })
end

M.enable_builtin = function()
	local cfg = M.config.builtin
	hl.monitor({ output = cfg.name, mode = "preferred", position = "auto", scale = cfg.scale, disabled = false })
end

M.monitor_status = function()
	local r_monitor = M.right()
	local l_monitor = M.left()
	local b_monitor = M.builtin()

	local function fmt(m)
		if m == nil then return "\t(not active)" end
		return "\tID: " .. m.id .. "\n\tNAME: " .. m.name .. "\n\tDESCRIPTION: " .. m.description
	end

	local buffer = {
		"RIGHT MONITOR", fmt(r_monitor), "",
		"LEFT MONITOR",  fmt(l_monitor), "",
		"BUILT-IN",      fmt(b_monitor),
	}

	hl.notification.create({
		text = table.concat(buffer, "\n"),
		timeout = 5000,
	})
end

return M
