# Keybinds

Defined in [`hyprland/dotfiles/.config/hypr/modules/keybinds.lua`](../hyprland/dotfiles/.config/hypr/modules/keybinds.lua).
That file is the source of truth — this doc can drift. For the live list
straight from Hyprland, press `SUPER + K` or run `hypr-show-keybinds` any
time.

`SUPER` is the main modifier (`MAIN_MOD` in `modules/globals.lua`).

## Applications

| Keybind | Action |
| --- | --- |
| `SUPER + Return` | Launch terminal |
| `SUPER + Space` | Launch app launcher |
| `SUPER + B` | Launch browser |
| `SUPER + E` | Launch file manager |
| `SUPER + N` | Launch notes |
| `SUPER + K` | Show keybinds (this list, live) |

## Screenshots

| Keybind | Action |
| --- | --- |
| `SUPER + Print` | Screenshot (fullscreen) |
| `SUPER + SHIFT + Print` | Screenshot (region select) |

## Windows

| Keybind | Action |
| --- | --- |
| `SUPER + Q` | Close current window |
| `SUPER` + left mouse drag | Drag window |
| `SUPER + SHIFT` + left mouse drag | Resize window |
| `SUPER + F` | Fullscreen (fill window) |
| `SUPER + SHIFT + F` | Fullscreen (fill workspace) |
| `SUPER + L` | Cycle to next window |
| `SUPER + H` | Cycle to previous window |

## Layouts

| Keybind | Action |
| --- | --- |
| `SUPER + SHIFT + Space` | Cycle window layout (scrolling → dwindle → master) |

## Workspaces

| Keybind | Action |
| --- | --- |
| `SUPER + 1`–`0` | Go to workspace 1–10 |
| `SUPER + SHIFT + 1`–`0` | Move window to workspace 1–10 |
| `SUPER + SHIFT + ]` | Cycle to next workspace |
| `SUPER + SHIFT + [` | Cycle to previous workspace |
| `SUPER + SHIFT + ←` | Move current workspace to left monitor |
| `SUPER + SHIFT + →` | Move current workspace to right monitor |

## Gestures (touchpad)

| Gesture | Action |
| --- | --- |
| 3-finger horizontal swipe | Scroll |
| 3-finger horizontal swipe + SHIFT | Switch workspace |
| 3-finger swipe down + ALT | Close window |
| 4-finger pinch out | Fullscreen |

## System

| Keybind | Action |
| --- | --- |
| `SUPER + A` | Toggle notification center |
| `SUPER + SHIFT + R` | Restart theme (reload Rofi, Waybar, Hyprland) |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + S` | System control menu |
| `SUPER + SHIFT + N` | Toggle nightlight |
| `SUPER + SHIFT + W` | Change wallpaper |
| `SUPER + W` | Next wallpaper (from active theme) |
| `SUPER + CTRL + W` | Previous wallpaper |
| `SUPER + ALT + W` | Random wallpaper |

## Media

| Keybind | Action |
| --- | --- |
| Volume Up/Down | Adjust output volume |
| Mute | Toggle output mute |
| Mic Mute | Toggle input mute |
| Brightness Up/Down | Adjust screen brightness |
| Play/Pause, Next, Previous | Control media playback (via `playerctl`) |

Monitor layout and profile switching aren't bound to a keybind — see
[nwg-profiles.md](nwg-profiles.md).
</content>
