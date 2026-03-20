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

## Integration

tiler is imported by hkd as a SwiftPM dependency. See the
[hotkey](https://github.com/Naveen-Kannan/hotkey) repo for build and install instructions.

To wire up hotkeys, add bindings to `~/.config/hkd/config.json`:

```json
{
  "bindings": [
    { "trigger": "cmd+opt+left",  "on_press": "window.left_half" },
    { "trigger": "cmd+opt+right", "on_press": "window.right_half" },
    { "trigger": "cmd+opt+up",    "on_press": "window.maximize" }
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

## Status

- [x] left half
- [x] right half
- [x] maximize
- [ ] top half / bottom half
- [ ] center
