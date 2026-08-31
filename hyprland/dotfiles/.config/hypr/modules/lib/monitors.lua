local str = require("modules.lib.strings")

local function assign_workspaces_to_monitor(workspaces_per_monitor, monitor, priority)
  if monitor == nil then return end

  for i = 1, workspaces_per_monitor do
    local workspace = tostring((workspaces_per_monitor * priority + i) - workspaces_per_monitor)
    -- log:write("Binding workspace " .. workspace .. " to monitor " .. monitor.description .. "\n")
    local rule = {
      workspace = workspace,
      monitor = monitor.name,
      default = (i == 1)
    }
    hl.workspace_rule(rule)
    hl.dsp.workspace.move({ workspace = workspace, monitor = monitor.name })
  end
end

local function find_monitor_by_description(description)
  for _, monitor in hl.get_monitors() do
    if str.trim(str.substr_after(monitor)) == str.trim(description) then
      return monitor
    end
  end
end


local function move_workspace_to_monitor(ws, m)
    hl.notification.create({
        text = "Moved " .. ws .. " to " .. m,
        timeout = 2000
    })
end

M = {
  external = {
    right = "",
    left = "",
  },
  assign_workspaces_to_monitor = assign_workspaces_to_monitor,
  find_monitor_by_description = find_monitor_by_description,
  move_workspace_to_monitor = move_workspace_to_monitor
}

return M

