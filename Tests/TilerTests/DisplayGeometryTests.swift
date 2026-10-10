import Foundation
import Testing
@testable import Tiler

@Test func testGlobalCoordinatesForDisplaysAboveAndBelowPrimary() {
    let above = CGRect(x: -300, y: 900, width: 1600, height: 900)
    let below = CGRect(x: 100, y: -1200, width: 1920, height: 1200)
    #expect(DisplayGeometry.axFrame(above, primaryHeight: 900).minY == -900)
    #expect(DisplayGeometry.axFrame(below, primaryHeight: 900).minY == 900)
    #expect(DisplayGeometry.axFrame(above, primaryHeight: 900).minX == -300)
}

@Test func testLargestOverlapWinsForStraddlingWindow() {
    let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800),
                   CGRect(x: 1000, y: 300, width: 1000, height: 800)]
    #expect(DisplayGeometry.screenIndex(for: CGRect(x: 950, y: 400, width: 600, height: 300), screens: screens) == 1)
}

@Test func testDisconnectedDisplayFallsBackToNearestScreen() {
    let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800),
                   CGRect(x: -1000, y: 0, width: 1000, height: 800)]
    #expect(DisplayGeometry.screenIndex(for: CGRect(x: -2200, y: 0, width: 400, height: 300), screens: screens) == 1)
    #expect(DisplayGeometry.screenIndex(for: .zero, screens: []) == nil)
}

@Test func testDisplayOrderIsSpatialAndIndependentOfPrimary() {
    let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800),
                   CGRect(x: 1000, y: 100, width: 1000, height: 800),
                   CGRect(x: -1000, y: 0, width: 1000, height: 800),
                   CGRect(x: 0, y: -800, width: 1000, height: 800)]
    #expect(DisplayGeometry.orderedIndices(screens) == [2, 3, 0, 1])
}

@Test func coreLayoutsCoverVisibleAreaOnEveryDisplay() {
    for visible in [CGRect(x: -1168, y: 22, width: 1168, height: 733),
                    CGRect(x: 0, y: 30, width: 1920, height: 1050),
                    CGRect(x: 1920, y: 30, width: 1440, height: 2530)] {
        let left = DisplayGeometry.targetFrame(.leftHalf, visible: visible)
        let right = DisplayGeometry.targetFrame(.rightHalf, visible: visible)
        #expect(left.minX == visible.minX)
        #expect(right.maxX == visible.maxX)
        #expect(left.maxX == right.minX)
        #expect(left.height == visible.height && right.height == visible.height)
        #expect(DisplayGeometry.targetFrame(.maximize, visible: visible) == visible)
    }
}

@Test func quartersCoverOddSizedVisibleAreaWithoutGaps() {
    let visible = CGRect(x: -500, y: -900, width: 1001, height: 801)
    let tl = DisplayGeometry.targetFrame(.topLeft, visible: visible)
    let tr = DisplayGeometry.targetFrame(.topRight, visible: visible)
    let bl = DisplayGeometry.targetFrame(.bottomLeft, visible: visible)
    let br = DisplayGeometry.targetFrame(.bottomRight, visible: visible)
    #expect(tl.minY == visible.minY && tr.minY == visible.minY)
    #expect(bl.maxY == visible.maxY && br.maxY == visible.maxY)
    #expect(tl.maxY == bl.minY && tr.maxY == br.minY)
    #expect(tl.maxX == tr.minX && bl.maxX == br.minX)
    #expect(tl.union(tr).union(bl).union(br) == visible)
}

@Test func testAppMinimumSizeStillAnchorsInsideDestination() {
    let screen = CGRect(x: -1168, y: 22, width: 1168, height: 733)
    let requested = CGRect(x: -584, y: 22, width: 608, height: 733)
    #expect(DisplayGeometry.fitted(requested, in: screen) == CGRect(x: -608, y: 22, width: 608, height: 733))
    let oversized = CGRect(x: -600, y: 0, width: 2000, height: 1200)
    #expect(DisplayGeometry.fitted(oversized, in: screen).origin == screen.origin)
}

@Test func portraitTransferMustNotAcceptSourceDisplayHeight() {
    let target = CGRect(x: 1920, y: 30, width: 1440, height: 2530)
    #expect(!DisplayGeometry.matches(CGRect(x: 1920, y: 30, width: 1440, height: 1050), target))
    #expect(DisplayGeometry.matches(CGRect(x: 1920, y: 30, width: 1440, height: 2530), target))
}

@Test func verticalHalvesPartitionOffsetAndOddSizedDisplays() {
    for visible in [CGRect(x: -1168, y: 26, width: 1168, height: 729),
                    CGRect(x: 0, y: 30, width: 1920, height: 1050),
                    CGRect(x: 1920, y: -900, width: 1440, height: 2531)] {
        let top = DisplayGeometry.targetFrame(.topHalf, visible: visible)
        let bottom = DisplayGeometry.targetFrame(.bottomHalf, visible: visible)
        #expect(top.minY == visible.minY)
        #expect(top.maxY == bottom.minY)
        #expect(bottom.maxY == visible.maxY)
        #expect(top.minX == visible.minX && bottom.minX == visible.minX)
        #expect(top.width == visible.width && bottom.width == visible.width)
        #expect(top.union(bottom) == visible)
        #expect(top.intersection(bottom).height == 0)
    }
}
