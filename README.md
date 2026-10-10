# tiler

Rectangle-style window management for [hkd](https://github.com/Naveen-Kannan/hotkey).

Tiler is a Swift Package library — it has no process of its own. It plugs into hkd,
which handles hotkey registration and command dispatch.

## Commands

| Command | Action |
|---|---|
| `window.left_half` | Move focused window to left half of its screen |
| `window.right_half` | Move focused window to right half of its screen |
| `window.top_half` | Move focused window to top half of its screen |
| `window.bottom_half` | Move focused window to bottom half of its screen |
| `window.maximize` | Resize focused window to the screen's visible frame |
| `window.top_left` | Move focused window to the top-left quarter |
| `window.top_right` | Move focused window to the top-right quarter |
| `window.bottom_left` | Move focused window to the bottom-left quarter |
| `window.bottom_right` | Move focused window to the bottom-right quarter |
| `window.next_display` | Send focused window to the next monitor, wrapping around |
| `window.previous_display` | Send focused window to the previous monitor, wrapping around |
| `window.display_1` / `window.display_2` / `window.display_3` | Send focused window directly to monitor 1 / 2 / 3 |
| `window.pointer_display` | Bring focused window to the monitor under the pointer |

## Multiple monitors

The aim is to move a working window between displays without interrupting dictation,
app launchers, music controls, or the existing tiling shortcuts.

| Shortcut | Action |
|---|---|
| Command+Option+Up / Down | Top / bottom half |
| Command+Option+Shift+Up | Maximize |
| Command+Option+Shift+Down | Next monitor (with two monitors, swaps between them) |
| Command+Option+5 / 6 / 7 | Monitor 1 / 2 / 3 |
| Command+Option+0 | Monitor under the mouse pointer |

Monitor numbers follow the arrangement in macOS Displays: left to right, then top to
bottom for displays at the same horizontal position. Connecting or rearranging displays
can change these numbers. Screens are read on every command; no restart is needed.
Monitor moves maximize the focused window on the destination, including selection of
its current monitor. Use Command+Option+Left/Right afterward to choose a half. Maximize
fills the visible area while retaining a normal window; it does not create a fullscreen
Space. The destination excludes the Dock and menu bar. Windows spanning screens belong
to the display with the largest overlap. All coordinates use the primary display's origin,
including vertically offset displays.

A serial background queue performs Accessibility operations, so a slow target app cannot
block HK's keyboard callback. Placement temporarily disables `AXEnhancedUserInterface` when it was enabled, then
applies size, position, size, and final alignment in one operation. The original mode is
restored afterward and checked by reading it back. Some apps report `NotImplemented`
even though the write changes the value, so setter status alone cannot decide restoration.
The final bounds are checked, with up to eight position/size attempts if the
source display's constraints persist. Only mismatched bounds wait 30 ms between attempts
(on the worker queue) so the app can update its screen limits. Retries stop after 250 ms
or a setter failure, so a slow app does not cause an extended retry loop. No later timer replays an old command. See Rectangle's
[AccessibilityElement implementation](https://github.com/rxhanson/Rectangle/blob/main/Rectangle/AccessibilityElement.swift)
for the macOS behavior motivating this sequence.

Select the app/window first, then use a monitor shortcut. Only the focused window moves.
An absent monitor number or a native fullscreen window causes monitor commands to do
nothing. With one display, a monitor command maximizes on that display. macOS Spaces and app-enforced minimum sizes can limit placement.
The optional `window.previous_display` command is available through HK without an
additional default binding. Existing Command+Option+1–4 quarter bindings are preserved.

## Integration

tiler is imported by hkd as a SwiftPM dependency. See the
[hotkey](https://github.com/Naveen-Kannan/hotkey) repo for build and install instructions.

To wire up hotkeys, add bindings to `~/.config/hkd/config.json`:

```json
{
  "bindings": [
    { "trigger": "cmd+opt+left",  "on_press": "window.left_half" },
    { "trigger": "cmd+opt+right", "on_press": "window.right_half" },
    { "trigger": "cmd+opt+up",    "on_press": "window.top_half" },
    { "trigger": "cmd+opt+down",  "on_press": "window.bottom_half" },
    { "trigger": "cmd+opt+shift+up", "on_press": "window.maximize" },
    { "trigger": "cmd+opt+1",     "on_press": "window.top_right" },
    { "trigger": "cmd+opt+2",     "on_press": "window.top_left" },
    { "trigger": "cmd+opt+3",     "on_press": "window.bottom_left" },
    { "trigger": "cmd+opt+4",     "on_press": "window.bottom_right" },
    { "trigger": "cmd+opt+shift+down", "on_press": "window.next_display" },
    { "trigger": "cmd+opt+5",     "on_press": "window.display_1" },
    { "trigger": "cmd+opt+6",     "on_press": "window.display_2" },
    { "trigger": "cmd+opt+7",     "on_press": "window.display_3" },
    { "trigger": "cmd+opt+0",     "on_press": "window.pointer_display" }
  ]
}
```

## How it works

- `TilerCommands` exports a name and a `[String: () -> Void]` command map
- hkd registers each entry with its `CommandRouter` at startup
- When a hotkey fires, hkd dispatches the command string → tiler's handler runs in-process
- `WindowManager` gets the focused window via `AXUIElementCreateApplication`, determines
  which screen it's on, converts to AX coordinates, and sets position + size

Accessibility permission is managed by hkd (it's already required for the event tap).

## Floating Window Note

We investigated adding a "pin window on top" feature to `tiler`, but did not keep it.

Why it does not fit the current architecture:
- `tiler` runs as a normal external process using Accessibility (`AXUIElement`) against other apps' windows.
- From that position, we can resize, move, and raise a foreign window, but we do not control its real window level.
- A polling loop that repeatedly calls `kAXRaiseAction` is only a best-effort re-raise. It cannot provide true always-on-top behavior while you continue interacting normally with other apps.
- More aggressive versions of this idea typically steal focus or fight app activation, which is not a clean fit for this project.

What would be required for a future extension:
- A separate experimental helper based on injection/private window APIs, similar in spirit to AfloatX. This can provide real floating behavior, but is less stable and carries higher maintenance risk.
- Or a separate overlay-style helper that owns its own floating window instead of trying to promote another app's real window.

For now, `tiler` stays focused on lightweight, explicit window movement and sizing.

## Status

- [x] left half
- [x] right half
- [x] maximize
- [x] top left
- [x] top right
- [x] bottom left
- [x] bottom right
- [x] next / previous monitor
- [x] direct monitor selection
- [x] move to pointer monitor
- [x] top half / bottom half
- [ ] center
