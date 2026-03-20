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

    // Returns the screen whose frame has the largest intersection with the window.
    // Using intersection area is robust against boundary edge cases and windows
    // that straddle two screens — unlike a simple point-containment check.
    private static func screen(for window: AXUIElement) -> NSScreen? {
        guard let axRect = axFrame(of: window) else { return NSScreen.main }

        // Convert AX rect to AppKit coordinates for comparison with NSScreen frames.
        let mainHeight = NSScreen.main?.frame.height ?? 0
        let appKitRect = CGRect(
            x: axRect.minX,
            y: mainHeight - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )

        return NSScreen.screens.max {
            intersectionArea($0.frame, appKitRect) < intersectionArea($1.frame, appKitRect)
        } ?? NSScreen.main
    }

    // Returns the target AX-coordinate frame for the given half of the screen's
    // visible area (i.e. excluding menu bar and Dock).
    private static func targetFrame(_ half: Half, on screen: NSScreen) -> CGRect {
        let visible    = screen.visibleFrame                // AppKit (bottom-left origin)
        let mainHeight = NSScreen.main?.frame.height ?? screen.frame.height

        // Convert visible frame top-left from AppKit to AX coordinates.
        let axY = mainHeight - visible.maxY
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

    // MARK: - Helpers

    private static func axFrame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let pv = posRef, let sv = sizeRef
        else { return nil }

        var origin = CGPoint.zero
        var size   = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
