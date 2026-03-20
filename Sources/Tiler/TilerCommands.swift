// TilerCommands — plug into hkd via daemon.add(TilerCommands())
//
// Registers window management commands with the hotkey daemon.
// hkd maps hotkeys → command strings; this provides the handlers.

public struct TilerCommands {
    public let name = "tiler"

    public let commands: [String: () -> Void] = [
        "window.left_half":  { WindowManager.leftHalf() },
        "window.right_half": { WindowManager.rightHalf() },
        "window.maximize":   { WindowManager.maximize() },
        "window.raise":      { WindowManager.raise() },
    ]

    public init() {}
}
