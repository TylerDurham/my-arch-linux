
local monitors = require("modules.monitors")

local known_workspaces = { [1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true }

local function apply_rules()
	local right_monitor = monitors.right()
	local left_monitor = monitors.left()

	if right_monitor ~= nil then
		for i = 1, 5 do
			hl.workspace_rule({ workspace = tostring(i), monitor = right_monitor.name, default = (i == 1), persistent = true })
			hl.dsp.workspace.move({ workspace = tostring(i), monitor = right_monitor.name })
		end
	end

	if left_monitor ~= nil then
		for i = 6, 10 do
			hl.workspace_rule({ workspace = tostring(i), monitor = left_monitor.name, default = (i == 6), persistent = true })
			hl.dsp.workspace.move({ workspace = tostring(i), monitor = left_monitor.name })
		end
	end
end

apply_rules()

hl.on("monitor.added", function()
	local docked = monitors.right() ~= nil or monitors.left() ~= nil
	if docked then
		monitors.disable_builtin()
	end

	apply_rules()

	-- Close any workspaces Hyprland auto-created for the new monitor
	for _, ws in ipairs(hl.get_workspaces()) do
		if not known_workspaces[ws.id] then
			hl.dispatch(hl.dsp.workspace.close({ workspace = tostring(ws.id) }))
		end
	end
end)

hl.on("monitor.removed", function()
	local docked = monitors.right() ~= nil or monitors.left() ~= nil
	if not docked then
		monitors.enable_builtin()
	end
end)
