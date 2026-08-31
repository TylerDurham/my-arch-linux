-- ###################################################
--
-- ████████╗██╗  ██╗███████╗███╗   ███╗███████╗
-- ╚══██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝
--    ██║   ███████║█████╗  ██╔████╔██║█████╗
--    ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝
--    ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗
--    ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝
-- ###################################################
--
-- Reads the palette of the currently applied theme so the Lua config can be
-- themed the same way waybar.css and rofi.rasi are.
--
-- ~/.config/my/theme is a symlink that hypr-set-current-theme repoints, and
-- hypr-restart-theme finishes with `hyprctl reload` — which re-evaluates this
-- config — so colors follow the active theme with no codegen step.
--
-- Sources are tried in order, since themes don't all carry the same files:
--   1. hyprland.conf   ($name = rgb(RRGGBB))      — lovely-day, catppuccin-mocha
--   2. @palette.toml   (name = "#RRGGBB")         — same two, richer set
--   3. colors.toml     (name = "#RRGGBB")         — the older omarchy-style themes
--
-- Anything still missing falls back to DEFAULTS, so a half-populated theme
-- degrades to sane borders instead of breaking the config.

local home = os.getenv("HOME")
local THEME_DIR = home .. "/.config/my/theme"

-- Ayu-ish values matching the previous hardcoded looknfeel colors.
local DEFAULTS = {
	accent1 = "FFCC00",
	accent2 = "39BAE6",
	background = "0D1017",
	foreground = "BFBDB6",
}

-- colors.toml uses a flat omarchy vocabulary; map it onto ours.
local ALIASES = {
	accent = "accent1",
	color4 = "accent2",
}

local colors = {}

local function read_lines(path)
	local fh = io.open(path, "r")
	if not fh then
		return nil
	end

	local lines = {}
	for line in fh:lines() do
		lines[#lines + 1] = line
	end
	fh:close()

	return lines
end

-- Only fill a key once: earlier sources win over later ones.
local function set(key, hex)
	key = ALIASES[key] or key
	if key and hex and not colors[key] then
		colors[key] = hex:upper()
	end
end

-- $accent1 = rgb(CBA6F7)   /   $accent1_trans = rgba(CBA6F755)
local function parse_hyprland_conf(lines)
	for _, line in ipairs(lines) do
		local key, hex = line:match("^%s*%$([%w_]+)%s*=%s*rgba?%(([0-9a-fA-F]+)%)")
		-- Skip the pre-baked translucent variants; alpha is applied below.
		if key and hex and #hex == 6 then
			set(key, hex)
		end
	end
end

-- accent1 = "#CBA6F7"
local function parse_toml(lines)
	for _, line in ipairs(lines) do
		local key, hex = line:match('^%s*([%w_]+)%s*=%s*"#([0-9a-fA-F]+)"')
		if key and hex and #hex == 6 then
			set(key, hex)
		end
	end
end

for _, source in ipairs({
	{ file = "/hyprland.conf", parse = parse_hyprland_conf },
	{ file = "/@palette.toml", parse = parse_toml },
	{ file = "/colors.toml", parse = parse_toml },
}) do
	local lines = read_lines(THEME_DIR .. source.file)
	if lines then
		source.parse(lines)
	end
end

local M = {}

-- Bare "RRGGBB" for the named color, falling back to the built-in default.
function M.hex(name)
	return colors[name] or DEFAULTS[name] or DEFAULTS.foreground
end

-- "rgba(RRGGBBAA)" — alpha is a two-digit hex string, defaulting to opaque.
function M.rgba(name, alpha)
	return string.format("rgba(%s%s)", M.hex(name), alpha or "ff")
end

-- "rgb(RRGGBB)"
function M.rgb(name)
	return string.format("rgb(%s)", M.hex(name))
end

M.colors = colors

return M
