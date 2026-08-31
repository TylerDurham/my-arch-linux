-- ###################################
--
-- ███████╗███╗   ██╗██╗   ██╗███████╗
-- ██╔════╝████╗  ██║██║   ██║██╔════╝
-- █████╗  ██╔██╗ ██║██║   ██║███████╗
-- ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝╚════██║
-- ███████╗██║ ╚████║ ╚████╔╝ ███████║
-- ╚══════╝╚═╝  ╚═══╝  ╚═══╝  ╚══════╝
-- ###################################

local home = os.getenv("HOME")

hl.env("CLUTTER_BACKEND", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MY_LIB_DIR", home .. "/.local/share/my/lib")
hl.env("NEWT_COLORS", home .. "/.config/my/theme/nmtui.colors")
hl.env("NEWT_COLORS_FILE", home .. "/.config/my/theme/nmtui.colors")
-- Hyprland does not shell-expand $VAR in env values, so splice in the real PATH
hl.env("PATH", home .. "/.local/share/my/bin:" .. home .. "/.local/bin:" .. os.getenv("PATH"))
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
