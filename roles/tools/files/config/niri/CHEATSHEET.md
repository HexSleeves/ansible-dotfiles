# niri + DankMaterialShell — Keybind Cheatsheet

`Mod` = `Super` (Windows key).

## Live overlay

| Key | Action |
|---|---|
| `Mod+Shift+/` | Niri's built-in hotkey overlay (every binding shown live) |
| `Mod+/` | DMS Cheatsheet panel (searchable) |

## Apps & shell

| Key | Action |
|---|---|
| `Mod+T` | Terminal (`alacritty`) |
| `Mod+D` | App launcher (DMS Spotlight) |
| `Mod+N` | Toggle notification drawer (DMS) |
| `Mod+M` | Toggle Control Center (DMS) |
| `Super+Alt+L` | Lock screen (DMS) |
| `Super+Alt+S` | Toggle Orca screen reader |

## Window basics

| Key | Action |
|---|---|
| `Mod+Q` | Close window |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Fullscreen window |
| `Mod+Ctrl+F` | Expand column to available width |
| `Mod+C` | Center current column |
| `Mod+Ctrl+C` | Center all visible columns |
| `Mod+V` | Toggle window floating |
| `Mod+Shift+V` | Switch focus floating ↔ tiling |
| `Mod+W` | Toggle column tabbed display |
| `Mod+R` | Cycle preset column widths |
| `Mod+Shift+R` | Cycle preset window heights |
| `Mod+Ctrl+R` | Reset window height |
| `Mod+-` / `Mod+=` | Column width −10% / +10% |
| `Mod+Shift+-` / `Mod+Shift+=` | Window height −10% / +10% |

## Focus (within monitor)

| Key | Action |
|---|---|
| `Mod+H` / `Mod+Left` | Focus column left |
| `Mod+L` / `Mod+Right` | Focus column right |
| `Mod+J` / `Mod+Down` | Focus window down (in column) |
| `Mod+K` / `Mod+Up` | Focus window up (in column) |
| `Mod+Home` / `Mod+End` | First / last column on workspace |

## Move windows

| Key | Action |
|---|---|
| `Mod+Ctrl+H/J/K/L` | Move column / window in direction |
| `Mod+Ctrl+Home/End` | Move column to first / last position |
| `Mod+[` / `Mod+]` | Consume / expel window into adjacent column |
| `Mod+,` | Consume window into current column |
| `Mod+.` | Expel window from current column |

## Workspaces

| Key | Action |
|---|---|
| `Mod+U` / `Mod+I` | Focus workspace down / up |
| `Mod+PageDown` / `Mod+PageUp` | Same as above |
| `Mod+Tab` | Focus previous workspace |
| `Mod+1` … `Mod+9` | Jump to workspace N |
| `Mod+F1` | Focus **term** workspace |
| `Mod+F2` | Focus **code** workspace |
| `Mod+F3` | Focus **browser** workspace |
| `Mod+Ctrl+U/I` | Move column to workspace down / up |
| `Mod+Ctrl+1` … `Mod+Ctrl+9` | Move column to workspace N |
| `Mod+Ctrl+F1`–`F3` | Move column to named workspace |
| `Mod+Shift+U/I` | Move whole workspace down / up |
| `Mod+ScrollWheel` | Scroll between workspaces |

## Multi-monitor

| Key | Action |
|---|---|
| `Mod+Shift+H/J/K/L` | Focus monitor in direction |
| `Mod+Shift+Arrow` | Same as above |
| `Mod+Shift+Ctrl+H/J/K/L` | Move column to adjacent monitor |

## Overview & screenshots

| Key | Action |
|---|---|
| `Mod+O` | Toggle Overview |
| `Print` | Interactive screenshot (region) |
| `Ctrl+Print` | Screenshot whole screen |
| `Alt+Print` | Screenshot focused window |

## Media / brightness

| Key | Action |
|---|---|
| `XF86AudioRaise/Lower/Mute` | Volume ±10% / mute (`wpctl`) |
| `XF86AudioMicMute` | Mic mute toggle |
| `XF86AudioPlay/Stop/Prev/Next` | `playerctl` controls |
| `XF86MonBrightnessUp/Down` | Backlight ±10% (`brightnessctl`) |

## Mouse / touchpad

| Action | Effect |
|---|---|
| `Mod` + drag (LMB) | Move window |
| `Mod` + drag (RMB) | Resize column |
| `Mod` + horizontal scroll | Move along the strip |
| 3-finger horizontal swipe | Scroll columns |
| 4-finger swipe up | Open Overview |

## Session

| Key | Action |
|---|---|
| `Mod+Escape` | Toggle keyboard-shortcuts inhibit (for VMs / nested compositors) |
| `Mod+Shift+E` | Quit niri |

## DMS CLI quick reference

```sh
dms doctor                 # health check
dms keybinds show niri     # JSON dump of effective bindings
dms ipc call spotlight toggle
dms ipc call controlCenter toggle
dms ipc call notifications toggle
dms ipc call cheatsheet toggle
dms ipc call lock lock
```

## Files

- `~/.config/niri/config.kdl` — main config (live-reloads on save)
- `~/.config/niri/CHEATSHEET.md` — this file
- `/usr/share/doc/niri/default-config.kdl.gz` — pristine default
- `~/.config/DankMaterialShell/` — DMS settings & themes

## Validate before logging out

```sh
niri validate -c ~/.config/niri/config.kdl
```
