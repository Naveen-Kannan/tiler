# tiler

Rectangle-style window management for [hkd](https://github.com/Naveen-Kannan/hotkey).

Tiler is a Swift Package library — it has no process of its own. It plugs into hkd,
which handles hotkey registration and command dispatch.

## Commands

| Command | Action |
|---|---|
| `window.left_half` | Move focused window to left half of its screen |
| `window.right_half` | Move focused window to right half of its screen |
| `window.maximize` | Resize focused window to the screen's visible frame |
| `window.top_left` | Move focused window to the top-left quarter |
| `window.top_right` | Move focused window to the top-right quarter |
| `window.bottom_left` | Move focused window to the bottom-left quarter |
| `window.bottom_right` | Move focused window to the bottom-right quarter |

## Integration

tiler is imported by hkd as a SwiftPM dependency. See the
[hotkey](https://github.com/Naveen-Kannan/hotkey) repo for build and install instructions.

To wire up hotkeys, add bindings to `~/.config/hkd/config.json`:

```json
{
  "bindings": [
    { "trigger": "cmd+opt+left",  "on_press": "window.left_half" },
    { "trigger": "cmd+opt+right", "on_press": "window.right_half" },
    { "trigger": "cmd+opt+up",    "on_press": "window.maximize" },
    { "trigger": "cmd+opt+1",     "on_press": "window.top_left" },
    { "trigger": "cmd+opt+2",     "on_press": "window.top_right" },
    { "trigger": "cmd+opt+3",     "on_press": "window.bottom_left" },
    { "trigger": "cmd+opt+4",     "on_press": "window.bottom_right" }
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
- [ ] top half / bottom half
- [ ] center
