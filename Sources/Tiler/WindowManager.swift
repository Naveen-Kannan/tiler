import AppKit
import os

// AppKit snapshots run on the main queue; AX work is serialized off it.
enum WindowManager {
    private static let log = Logger(subsystem: "com.nkannan.tiler", category: "placement")
    private static let queue = DispatchQueue(label: "com.nkannan.tiler", qos: .userInitiated)

    private struct Context: Sendable {
        let pid: pid_t
        let screens: [CGRect]
        let visible: [CGRect]
        let pointerIndex: Int?
    }

    static func leftHalf()  { resize(.leftHalf) }
    static func rightHalf() { resize(.rightHalf) }
    static func topHalf()  { resize(.topHalf) }
    static func bottomHalf() { resize(.bottomHalf) }
    static func maximize()  { resize(.maximize) }
    static func topLeft()   { resize(.topLeft) }
    static func topRight()  { resize(.topRight) }
    static func bottomLeft() { resize(.bottomLeft) }
    static func bottomRight() { resize(.bottomRight) }
    static func nextDisplay() { moveDisplay(step: 1) }
    static func previousDisplay() { moveDisplay(step: -1) }
    static func display(_ number: Int) { moveDisplay(number: number) }
    static func pointerDisplay() { moveDisplay(toPointer: true) }

    private static func perform(_ action: @escaping @Sendable (Context) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { enqueue(action) }
        } else {
            DispatchQueue.main.async { enqueue(action) }
        }
    }

    @MainActor
    private static func enqueue(_ action: @escaping @Sendable (Context) -> Void) {
        let screens = NSScreen.screens
        guard let primary = screens.first, let app = NSWorkspace.shared.frontmostApplication else { return }
        let context = Context(
            pid: app.processIdentifier,
            screens: screens.map { DisplayGeometry.axFrame($0.frame, primaryHeight: primary.frame.height) },
            visible: screens.map { DisplayGeometry.axFrame($0.visibleFrame, primaryHeight: primary.frame.height) },
            pointerIndex: screens.firstIndex { $0.frame.contains(NSEvent.mouseLocation) }
        )
        queue.async { action(context) }
    }

    private static func resize(_ layout: DisplayGeometry.Layout) {
        perform { context in
            guard let window = frontmostWindow(pid: context.pid), let frame = windowFrame(window),
                  let index = DisplayGeometry.screenIndex(for: frame, screens: context.screens) else { return }
            let visible = context.visible[index]
            set(window: window, to: DisplayGeometry.targetFrame(layout, visible: visible), within: visible)
        }
    }

    private static func moveDisplay(step: Int = 0, number: Int? = nil, toPointer: Bool = false) {
        perform { context in
            guard let window = frontmostWindow(pid: context.pid), let frame = windowFrame(window),
                  let source = DisplayGeometry.screenIndex(for: frame, screens: context.screens) else { return }
            let order = DisplayGeometry.orderedIndices(context.screens)
            let target: Int
            if toPointer {
                guard let index = context.pointerIndex else { return }
                target = index
            } else if let number {
                guard number > 0, number <= order.count else { return }
                target = order[number - 1]
            } else {
                guard let index = order.firstIndex(of: source) else { return }
                target = order[(index + step + order.count) % order.count]
            }
            let visible = context.visible[target]
            set(window: window, to: visible, within: visible)
        }
    }

    private static func frontmostWindow(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.6)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        let window = ref as! AXUIElement
        AXUIElementSetMessagingTimeout(window, 0.6)
        var fullScreen: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreen)
        guard (fullScreen as? Bool) != true else { return nil }
        return window
    }

    private static func windowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func set(window: AXUIElement, to frame: CGRect, within bounds: CGRect) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2)
        let enhancedAttribute = "AXEnhancedUserInterface" as CFString
        var enhanced: CFTypeRef?
        AXUIElementCopyAttributeValue(app, enhancedAttribute, &enhanced)
        let wasEnhanced = (enhanced as? Bool) == true
        let suppression = wasEnhanced
            ? AXUIElementSetAttributeValue(app, enhancedAttribute, kCFBooleanFalse) : .success
        defer {
            // Some apps apply this write even while reporting NotImplemented.
            if wasEnhanced {
                AXUIElementSetAttributeValue(app, enhancedAttribute, kCFBooleanTrue)
                var restored: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(app, enhancedAttribute, &restored)
                if result != .success || (restored as? Bool) != true {
                    log.error("enhanced UI mode was not restored")
                }
            }
        }

        var origin = frame.origin, size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin),
              let dimensions = AXValueCreate(.cgSize, &size) else { return }
        // The source display can constrain size until the app processes the move.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        var attempts = 0
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        for attempt in 0..<8 {
            attempts += 1
            let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
            let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
            if positionResult != .success || sizeResult != .success {
                log.error("placement failed: position=\(positionResult.rawValue), size=\(sizeResult.rawValue)")
                break
            }
            guard let actual = windowFrame(window) else { break }
            if DisplayGeometry.matches(actual, frame) { break }
            origin = DisplayGeometry.fitted(CGRect(origin: frame.origin, size: actual.size), in: bounds).origin
            if actual.origin != origin, let aligned = AXValueCreate(.cgPoint, &origin) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, aligned)
            }
            // Some apps update screen constraints on their next event-loop turn.
            // Keep corrections in this command, off the keyboard callback.
            guard attempt < 7, ProcessInfo.processInfo.systemUptime < deadline else { break }
            Thread.sleep(forTimeInterval: 0.03)
        }
        if let actual = windowFrame(window) {
            log.notice("placed pid=\(pid) enhancedUI=\(wasEnhanced) suppression=\(suppression.rawValue) attempts=\(attempts) target=\(String(describing: frame), privacy: .public) actual=\(String(describing: actual), privacy: .public)")
        }
    }
}
