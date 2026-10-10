// TilerCommands — plug into hkd via daemon.add(TilerCommands())
//
// Registers window management commands with the hotkey daemon.
// hkd maps hotkeys → command strings; this provides the handlers.

public struct TilerCommands {
    public let name = "tiler"

    public let commands: [String: () -> Void] = [
        "window.left_half":  { WindowManager.leftHalf() },
        "window.right_half": { WindowManager.rightHalf() },
        "window.top_half":   { WindowManager.topHalf() },
        "window.bottom_half": { WindowManager.bottomHalf() },
        "window.maximize":   { WindowManager.maximize() },
        "window.top_left":   { WindowManager.topLeft() },
        "window.top_right":  { WindowManager.topRight() },
        "window.bottom_left": { WindowManager.bottomLeft() },
        "window.bottom_right": { WindowManager.bottomRight() },
        "window.next_display": { WindowManager.nextDisplay() },
        "window.previous_display": { WindowManager.previousDisplay() },
        "window.display_1": { WindowManager.display(1) },
        "window.display_2": { WindowManager.display(2) },
        "window.display_3": { WindowManager.display(3) },
        "window.pointer_display": { WindowManager.pointerDisplay() },
    ]

    public init() {}
}
