import AppKit

enum WindowManager {
    static func leftHalf()  { resize(.leftHalf) }
    static func rightHalf() { resize(.rightHalf) }

    // MARK: - Private

    private enum Half { case leftHalf, rightHalf }

    private static func resize(_ half: Half) {
        guard let window = frontmostWindow() else { return }
        guard let screen  = screen(for: window) else { return }
        let frame = targetFrame(half, on: screen)
        set(window: window, to: frame)
    }

    // Returns the AXUIElement for the focused window of the frontmost app.
    private static func frontmostWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success else {
            return nil
        }
        return (ref as! AXUIElement)
    }

    // Finds which NSScreen the window's top-left corner currently sits on.
    // Falls back to the primary screen.
    private static func screen(for window: AXUIElement) -> NSScreen? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &ref) == .success,
              let val = ref else { return NSScreen.main }

        var axOrigin = CGPoint.zero
        AXValueGetValue(val as! AXValue, .cgPoint, &axOrigin)

        // AX uses top-left origin; NSScreen uses bottom-left.
        // Convert axOrigin to AppKit coordinates to find the right screen.
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitPoint  = CGPoint(x: axOrigin.x, y: screenHeight - axOrigin.y)

        return NSScreen.screens.first { $0.frame.contains(appKitPoint) } ?? NSScreen.main
    }

    // Returns the target AX-coordinate frame for the given half of the screen's
    // visible area (i.e. excluding menu bar and Dock).
    private static func targetFrame(_ half: Half, on screen: NSScreen) -> CGRect {
        let visible      = screen.visibleFrame                         // AppKit (bottom-left origin)
        let screenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        // Top of the visible area in AX coordinates
        let axY = screenHeight - visible.maxY
        let axX = visible.minX
        let w   = floor(visible.width / 2)
        let h   = visible.height

        switch half {
        case .leftHalf:  return CGRect(x: axX,     y: axY, width: w, height: h)
        case .rightHalf: return CGRect(x: axX + w, y: axY, width: w, height: h)
        }
    }

    private static func set(window: AXUIElement, to frame: CGRect) {
        var origin = frame.origin
        var size   = frame.size
        if let posVal  = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
    }
}
