import Foundation

enum DisplayGeometry {
    // AX uses the primary display's top-left as the origin for every display.
    static func axFrame(_ frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY,
               width: frame.width, height: frame.height)
    }

    static func screenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let overlaps = screens.map { screen -> CGFloat in
            let intersection = screen.intersection(window)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let index = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[index] > 0 {
            return index
        }
        return screens.indices.min { a, b in
            distance(window, screens[a]) < distance(window, screens[b])
        }
    }

    static func orderedIndices(_ screens: [CGRect]) -> [Int] {
        screens.indices.sorted { a, b in
            if screens[a].minX != screens[b].minX { return screens[a].minX < screens[b].minX }
            if screens[a].minY != screens[b].minY { return screens[a].minY < screens[b].minY }
            return a < b
        }
    }

    enum Layout: Sendable {
        case leftHalf, rightHalf, topHalf, bottomHalf, maximize, topLeft, topRight, bottomLeft, bottomRight
    }

    // Frames are already in AX coordinates: increasing Y points down.
    static func targetFrame(_ layout: Layout, visible: CGRect) -> CGRect {
        let leftWidth = floor(visible.width / 2), topHeight = floor(visible.height / 2)
        var frame = visible
        switch layout {
        case .maximize: break
        case .leftHalf: frame.size.width = leftWidth
        case .rightHalf: frame.origin.x += leftWidth; frame.size.width -= leftWidth
        case .topHalf: frame.size.height = topHeight
        case .bottomHalf: frame.origin.y += topHeight; frame.size.height -= topHeight
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let right = layout == .topRight || layout == .bottomRight
            let top = layout == .topLeft || layout == .topRight
            frame.origin.x += right ? leftWidth : 0
            frame.size.width = right ? visible.width - leftWidth : leftWidth
            frame.origin.y += top ? 0 : topHeight
            frame.size.height = top ? topHeight : visible.height - topHeight
        }
        return frame
    }

    static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) < 2 && abs(actual.minY - target.minY) < 2 &&
        abs(actual.width - target.width) < 2 && abs(actual.height - target.height) < 2
    }

    static func fitted(_ frame: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(x: min(max(frame.minX, bounds.minX), max(bounds.minX, bounds.maxX - frame.width)),
               y: min(max(frame.minY, bounds.minY), max(bounds.minY, bounds.maxY - frame.height)),
               width: frame.width, height: frame.height)
    }

    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX, dy = a.midY - b.midY
        return dx * dx + dy * dy
    }
}
