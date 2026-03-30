import AppKit

enum WindowManager {
    static func leftHalf()  { resize(.leftHalf) }
    static func rightHalf() { resize(.rightHalf) }
    static func maximize()  { resize(.maximize) }
    static func topLeft()   { resize(.topLeft) }
    static func topRight()  { resize(.topRight) }
    static func bottomLeft() { resize(.bottomLeft) }
    static func bottomRight() { resize(.bottomRight) }

    // MARK: - Private

    private enum Layout {
        case leftHalf
        case rightHalf
        case maximize
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private static func resize(_ layout: Layout) {
        guard let window = frontmostWindow() else { return }
        guard let screen = screen(for: window) else { return }
        let frame = targetFrame(layout, on: screen)
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
        return NSScreen.screens.first { contains(axOrigin, in: $0) } ?? NSScreen.main
    }

    // Returns the target AX-coordinate frame for the given half of the screen's
    // visible area (i.e. excluding menu bar and Dock).
    private static func targetFrame(_ layout: Layout, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame                              // AppKit (bottom-left origin)
        let leftWidth = floor(visible.width / 2)
        let rightWidth = visible.width - leftWidth
        let topHeight = floor(visible.height / 2)
        let bottomHeight = visible.height - topHeight

        switch layout {
        case .leftHalf:
            return axFrame(
                x: visible.minX,
                appKitMinY: visible.minY,
                width: leftWidth,
                height: visible.height,
                on: screen
            )
        case .rightHalf:
            return axFrame(
                x: visible.minX + leftWidth,
                appKitMinY: visible.minY,
                width: rightWidth,
                height: visible.height,
                on: screen
            )
        case .maximize:
            return axFrame(
                x: visible.minX,
                appKitMinY: visible.minY,
                width: visible.width,
                height: visible.height,
                on: screen
            )
        case .topLeft:
            return axFrame(
                x: visible.minX,
                appKitMinY: visible.maxY - topHeight,
                width: leftWidth,
                height: topHeight,
                on: screen
            )
        case .topRight:
            return axFrame(
                x: visible.minX + leftWidth,
                appKitMinY: visible.maxY - topHeight,
                width: rightWidth,
                height: topHeight,
                on: screen
            )
        case .bottomLeft:
            return axFrame(
                x: visible.minX,
                appKitMinY: visible.minY,
                width: leftWidth,
                height: bottomHeight,
                on: screen
            )
        case .bottomRight:
            return axFrame(
                x: visible.minX + leftWidth,
                appKitMinY: visible.minY,
                width: rightWidth,
                height: bottomHeight,
                on: screen
            )
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

    private static func contains(_ axPoint: CGPoint, in screen: NSScreen) -> Bool {
        let screenFrame = screen.frame
        let appKitY = screenFrame.maxY - axPoint.y
        let appKitPoint = CGPoint(x: axPoint.x, y: appKitY)
        return screenFrame.contains(appKitPoint)
    }

    private static func axFrame(
        x: CGFloat,
        appKitMinY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        on screen: NSScreen
    ) -> CGRect {
        let axY = screen.frame.maxY - (appKitMinY + height)
        return CGRect(x: x, y: axY, width: width, height: height)
    }
}
