
local function makeConst(t)
	return setmetatable({}, {
		__index = t,
		__newindex = function(_, k, _)
			error("attempt to modify constant: " .. tostring(k), 2)
		end,
	})
end

M = {
	programs = makeConst({
		TERMINAL = "ghostty",
		FILE_MANAGER = "nautilus",
		APP_LAUNCHER = "~/.local/share/my/bin/hypr-launch-applications",
		BROWSER = "brave",
		NOTES = "obsidian",
	}),
	monitors = makeConst({
		EXTERNAL_RIGHT = "desc: LG Electronics LG ULTRAGEAR 404MXCR52499",
		EXTERNAL_LEFT = "desc: Dell Inc. DELL S2725QS 7DCMT84",
	}),
	keybinds = makeConst({
		MAIN_MOD = "SUPER",
	}),
}

return M
