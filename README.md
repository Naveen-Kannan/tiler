# Tiler

[![Tests](https://github.com/Naveen-Kannan/tiler/actions/workflows/tests.yml/badge.svg)](https://github.com/Naveen-Kannan/tiler/actions/workflows/tests.yml)

Window tiling for macOS, as a small Swift library. Move the focused window into
halves or quarters, maximize it, or send it to another display.

I wanted Rectangle-style controls as explicit hotkey commands inside my existing
hotkey host. Tiler runs in that host's process and exports a command dictionary.

## Build and test

- macOS 13 or newer.
- Swift 6 or newer to build and test. The tests use Swift Testing.

```sh
git clone https://github.com/Naveen-Kannan/tiler.git
cd tiler
swift build
swift test
```

The package has no external dependencies. CI runs the test suite on a standard
GitHub macOS runner after the repository is public.

## Use from a Swift host

Add Tiler as a Swift Package dependency:

```swift
.package(url: "https://github.com/Naveen-Kannan/tiler.git", branch: "main")
```

Add its library product to your host target's dependencies:

```swift
.product(name: "Tiler", package: "tiler")
```

Then connect a handler to your keyboard shortcut or command router:

```swift
import Tiler

@MainActor
func snapFocusedWindowLeft() {
    TilerCommands().commands["window.left_half"]?()
}
```

Handlers can be called from any thread. The command collection is `Sendable`;
Tiler snapshots the displays and active app on the main queue, then performs
Accessibility operations on a serial background queue. The host needs a running
main event loop, as a normal macOS application provides.
The host application needs macOS Accessibility permission to move other apps'
windows. My own host supplies shortcut registration, command dispatch, and that
permission; other hosts can use the same dictionary.

## Commands

| Command | Action |
|---|---|
| `window.left_half` / `window.right_half` | Left / right half of the current display |
| `window.top_half` / `window.bottom_half` | Top / bottom half |
| `window.maximize` | Fill the display's visible frame |
| `window.top_left` / `window.top_right` | Top-left / top-right quarter |
| `window.bottom_left` / `window.bottom_right` | Bottom-left / bottom-right quarter |
| `window.next_display` / `window.previous_display` | Move between displays, wrapping around |
| `window.display_1` / `window.display_2` / `window.display_3` | Move directly to a numbered display |
| `window.pointer_display` | Move to the display under the pointer |

## Displays and placement

Display numbers follow the arrangement in macOS: left to right, then top to
bottom when displays share an X coordinate. The list is read for each command,
so rearranging or reconnecting displays can change the numbers.

Moving to a display maximizes the window within its visible frame, excluding the
Dock and menu bar. Choose a half or quarter afterward for a smaller layout. A
window spanning displays belongs to the one with the largest overlap. Coordinates
use the primary display's top-left as their origin, including displays above or
below it.

Select the app and window before invoking a command. Native fullscreen windows
and unavailable display numbers are skipped. With one display, a display move
maximizes on that display. App minimum sizes, macOS Spaces, and application
Accessibility support can limit the result.

Commands retain the app and display context selected when queued. With a slow
target app, repeated commands can finish after focus has moved elsewhere.

## Implementation

- `TilerCommands` exposes the command names and handlers.
- `DisplayGeometry` handles coordinate conversion, display selection, and layouts.
- `WindowManager` reads the focused window through `AXUIElement` and applies its
  size and position off the keyboard callback.

Placement applies size, position, then size again, with bounded corrections if
an app retains constraints from the source display. Further attempts stop after
eight attempts, a setter failure, or the 250 ms retry budget. This budget limits
additional retries, rather than the total command duration: individual
Accessibility calls can take longer, up to their messaging timeouts. Corrections
stay within the original command rather than scheduling a later window move.

When needed, placement temporarily disables `AXEnhancedUserInterface`, then
restores and verifies its previous enabled state. This accommodates apps that
apply a change while reporting `NotImplemented`. Rectangle's
[AccessibilityElement implementation](https://github.com/rxhanson/Rectangle/blob/main/Rectangle/AccessibilityElement.swift)
provides background on this macOS behavior.

CI uses Swift 6 strict concurrency mode. Tests cover the command collection's task
and host compatibility, offset displays, overlap and fallback selection, spatial
display order, halves and quarters with odd dimensions, app minimum sizes, and
portrait monitor transfers. Window movement also depends on the target
application's Accessibility behavior.

## License

[MIT](LICENSE). Copyright © 2026 Naveen Kannan.
