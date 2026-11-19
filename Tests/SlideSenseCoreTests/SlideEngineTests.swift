import CoreGraphics
import XCTest
@testable import SlideSenseCore

private final class Recorder: SlideEngineDelegate {
    var begins: [EdgeAction] = []
    var updates: [(EdgeAction, Double)] = []
    var ends: [(EdgeAction, Double)] = []
    var ticks: [(EdgeAction, Double)] = []
    var commands: [MediaCommand] = []
    var tickDirections: [Bool] = []
    var bottomTickDirections: [Bool] = []

    func slideEngine(_ engine: SlideEngine, didBeginSlide target: EdgeAction) {
        begins.append(target)
    }

    func slideEngine(_ engine: SlideEngine, didUpdateSlide target: EdgeAction, level: Double) {
        updates.append((target, level))
    }

    func slideEngine(_ engine: SlideEngine, didEndSlide target: EdgeAction, level: Double) {
        ends.append((target, level))
    }

    func slideEngine(_ engine: SlideEngine, didTick target: EdgeAction, level: Double, increasing: Bool) {
        ticks.append((target, level))
        tickDirections.append(increasing)
    }

    func slideEngine(_ engine: SlideEngine, didTickBottomEdge increasing: Bool) {
        bottomTickDirections.append(increasing)
    }

    func slideEngine(_ engine: SlideEngine, didRecognize command: MediaCommand) {
        commands.append(command)
    }
}

final class SlideEngineTests: XCTestCase {
    private func makeEngine(_ configure: (inout EngineConfiguration) -> Void = { _ in }) -> (SlideEngine, Recorder) {
        let engine = SlideEngine()
        var config = EngineConfiguration()
        config.mediaStripEnabled = true
        configure(&config)
        engine.configuration = { config }
        engine.modifiers = { [] }
        let recorder = Recorder()
        engine.delegate = recorder
        return (engine, recorder)
    }

    private func frame(at time: TimeInterval, x: Double, y: Double, touching: Bool = true) -> TouchFrame {
        TouchFrame(timestamp: time, contacts: [TouchContact(id: 1, x: x, y: y, isTouching: touching)])
    }

    func testRightSlideSenseChangesVolume() {
        var config = EngineConfiguration()
        config.currentVolume = 0.5
        let (engine, recorder) = makeEngine { $0 = config }

        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
        engine.process(frame(at: 0.04, x: 0.95, y: 0.6))

        XCTAssertEqual(recorder.begins, [.volume])
        XCTAssertGreaterThan(recorder.updates.last?.1 ?? 0, 0.5)
        XCTAssertEqual(recorder.ends.count, 0) // still touching
    }

    func testLeftSlideSenseChangesBrightness() {
        var config = EngineConfiguration()
        config.currentBrightness = 0.5
        let (engine, recorder) = makeEngine { $0 = config }

        engine.process(frame(at: 0.0, x: 0.05, y: 0.8))
        engine.process(frame(at: 0.02, x: 0.05, y: 0.6))

        XCTAssertEqual(recorder.begins, [.brightness])
        XCTAssertEqual(recorder.updates.last?.1 ?? 1, 0.25, accuracy: 0.001)
    }

    func testMiddleTouchIsIgnored() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0.0, x: 0.5, y: 0.5))
        engine.process(frame(at: 0.02, x: 0.55, y: 0.55))
        XCTAssertTrue(recorder.begins.isEmpty)
        XCTAssertTrue(recorder.updates.isEmpty)
    }

    func testSecondFingerCancelsSlide() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
        let twoFingers = TouchFrame(timestamp: 0.04, contacts: [
            TouchContact(id: 1, x: 0.95, y: 0.5, isTouching: true),
            TouchContact(id: 2, x: 0.5, y: 0.5, isTouching: true)
        ])
        engine.process(twoFingers)
        XCTAssertEqual(recorder.ends.count, 1)
    }

    func testLevelStopsAtBounds() {
        var config = EngineConfiguration()
        config.currentVolume = 0.9
        let (engine, recorder) = makeEngine { $0 = config }
        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 1.0))
        XCTAssertEqual(recorder.updates.last?.1 ?? 0, 1.0, accuracy: 0.001)
    }

    func testDoubleTapCornerMutes() {
        let (engine, recorder) = makeEngine()
        for index in 0..<2 {
            let base = Double(index) * 0.2
            engine.process(frame(at: base + 0.00, x: 0.95, y: 0.95))
            engine.process(frame(at: base + 0.05, x: 0.95, y: 0.95))
            engine.process(frame(at: base + 0.08, x: 0.95, y: 0.95, touching: false))
        }
        XCTAssertEqual(recorder.commands, [.mute])
    }

    func testSingleCornerTapDoesNotMute() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0.0, x: 0.95, y: 0.95))
        engine.process(frame(at: 0.05, x: 0.95, y: 0.95))
        engine.process(frame(at: 0.08, x: 0.95, y: 0.95, touching: false))
        XCTAssertTrue(recorder.commands.isEmpty)
    }

    func testBottomStripSwipeSendsNext() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0.0, x: 0.8, y: 0.05))
        engine.process(frame(at: 0.02, x: 0.6, y: 0.05))
        engine.process(frame(at: 0.04, x: 0.4, y: 0.05))
        XCTAssertEqual(recorder.commands, [.next])
    }

    func testBottomStripReverseFlipsDirection() {
        let (engine, recorder) = makeEngine { $0.mediaStripReverse = true }
        engine.process(frame(at: 0.0, x: 0.2, y: 0.05))
        engine.process(frame(at: 0.04, x: 0.6, y: 0.05))
        XCTAssertEqual(recorder.commands, [.next])
    }

    func testDroppedContactKeepsSlideAlive() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
        // One stray frame with no contacts should not end the gesture.
        engine.process(TouchFrame(timestamp: 0.04, contacts: []))
        engine.process(frame(at: 0.05, x: 0.95, y: 0.55))
        XCTAssertEqual(recorder.begins.count, 1)
        XCTAssertEqual(recorder.ends.count, 0)
        XCTAssertGreaterThan(recorder.updates.last?.1 ?? 0, 0.5)
    }

    func testFineControlUsesQuarterSteps() {
        var config = EngineConfiguration()
        config.preciseSliding = true
        config.currentVolume = 0.5
        let (engine, recorder) = makeEngine { $0 = config }

        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.25))
        guard let level = recorder.updates.last?.1 else {
            return XCTFail("expected an update")
        }
        // Quarter steps land on multiples of 1/64.
        let scaled = level * 64
        XCTAssertEqual(scaled.rounded(), scaled, accuracy: 0.0001)
    }

    func testRequiredModifierBlocksSlide() {
        let engine = SlideEngine()
        var config = EngineConfiguration()
        config.requireModifier = .option
        engine.configuration = { config }
        engine.modifiers = { [] }
        let recorder = Recorder()
        engine.delegate = recorder

        engine.process(frame(at: 0.0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.6))
        XCTAssertTrue(recorder.updates.isEmpty)
    }
    func testModifierReleaseCancelsUntilLift() {
        let (engine, recorder) = makeEngine { $0.requireModifier = .option }
        var held: ModifierState = .option
        engine.modifiers = { held }
        engine.process(frame(at: 0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
        let count = recorder.updates.count
        held = []
        engine.process(frame(at: 0.04, x: 0.95, y: 0.6))
        held = .option
        engine.process(frame(at: 0.06, x: 0.95, y: 0.8))
        XCTAssertEqual(recorder.updates.count, count)
        XCTAssertEqual(recorder.ends.count, 1)
        XCTAssertFalse(engine.isTrackingSlide)
    }

    func testLeavingEdgeCancelsUntilLift() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0, x: 0.95, y: 0.2))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
        let count = recorder.updates.count
        engine.process(frame(at: 0.04, x: 0.5, y: 0.6))
        engine.process(frame(at: 0.06, x: 0.95, y: 0.8))
        XCTAssertEqual(recorder.updates.count, count)
        XCTAssertEqual(recorder.ends.count, 1)
        XCTAssertFalse(engine.isTrackingSlide)
    }

    func testLiftNewContactAndLongGapDoNotInheritSlide() {
        for ending in ["lift", "newContact", "gap", "emptyFrames"] {
            let (engine, recorder) = makeEngine()
            engine.process(frame(at: 0, x: 0.95, y: 0.2))
            engine.process(frame(at: 0.02, x: 0.95, y: 0.4))
            let count = recorder.updates.count
            switch ending {
            case "lift":
                engine.process(frame(at: 0.03, x: 0.95, y: 0.4, touching: false))
            case "emptyFrames":
                for index in 1...6 {
                    engine.process(TouchFrame(timestamp: 0.02 + Double(index) * 0.01, contacts: []))
                }
            default: break
            }
            engine.process(TouchFrame(timestamp: ending == "gap" ? 1 : 0.09, contacts: [
                TouchContact(id: ending == "newContact" ? 2 : 1, x: 0.5, y: 0.6, isTouching: true)
            ]))
            XCTAssertEqual(recorder.updates.count, count, ending)
            XCTAssertEqual(recorder.ends.count, 1, ending)
            XCTAssertFalse(engine.isTrackingSlide, ending)
        }
    }

    func testScreenshotSwipeEmitsOnceInEitherDirection() {
        for end in [0.25, 0.75] {
            let (engine, recorder) = makeEngine { $0.bottomEdgeAction = .screenshot }
            engine.process(frame(at: 0, x: 0.5, y: 0.05))
            engine.process(frame(at: 0.02, x: end, y: 0.05))
            engine.process(frame(at: 0.04, x: end, y: 0.05))
            XCTAssertEqual(recorder.commands, [.screenshot])
        }
    }

    func testScreenshotModeDoesNotPlayOnDoubleTap() {
        let (engine, recorder) = makeEngine {
            $0.bottomEdgeAction = .screenshot
            $0.tapToPlayEnabled = true
        }
        for base in [0.0, 0.2] {
            engine.process(frame(at: base, x: 0.5, y: 0.05))
            engine.process(frame(at: base + 0.05, x: 0.5, y: 0.05, touching: false))
        }
        XCTAssertTrue(recorder.commands.isEmpty)
    }

    func testSlideTicksReportDirectionChanges() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0, x: 0.95, y: 0.3))
        engine.process(frame(at: 0.02, x: 0.95, y: 0.5))
        engine.process(frame(at: 0.04, x: 0.95, y: 0.4))
        XCTAssertEqual(recorder.tickDirections, [true, false])
    }

    func testSlideHapticPatternsDifferByDirection() {
        for strength in HapticStrength.allCases {
            XCTAssertNotEqual(Haptics.slidePattern(strength, increasing: true),
                              Haptics.slidePattern(strength, increasing: false))
        }
    }

    func testBottomEdgeTicksInBothModesAndDirections() {
        for action in BottomEdgeAction.allCases {
            let (engine, recorder) = makeEngine { $0.bottomEdgeAction = action }
            engine.process(frame(at: 0, x: 0.5, y: 0.05))
            engine.process(frame(at: 0.01, x: 0.51, y: 0.05))
            XCTAssertTrue(recorder.bottomTickDirections.isEmpty)
            engine.process(frame(at: 0.02, x: 0.57, y: 0.05))
            engine.process(frame(at: 0.03, x: 0.58, y: 0.05))
            engine.process(frame(at: 0.04, x: 0.5, y: 0.05))
            XCTAssertEqual(recorder.bottomTickDirections, [true, false])
        }
    }

    func testBottomSwipeToleratesDriftAndContinuesIntoCorner() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0, x: 0.2, y: 0.17))
        engine.process(frame(at: 0.02, x: 0.31, y: 0.20))
        engine.process(frame(at: 0.04, x: 0.95, y: 0.05))
        XCTAssertEqual(recorder.commands, [.previous])
        XCTAssertEqual(recorder.bottomTickDirections, [true, true])
    }

    func testBottomSwipeStillCancelsOutsideBand() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0, x: 0.5, y: 0.15))
        engine.process(frame(at: 0.02, x: 0.56, y: 0.25))
        engine.process(frame(at: 0.04, x: 0.75, y: 0.05))
        XCTAssertTrue(recorder.commands.isEmpty)
        XCTAssertTrue(recorder.bottomTickDirections.isEmpty)
    }

    func testBottomHapticsIgnoreJitterAroundOldStepBoundary() {
        let (engine, recorder) = makeEngine()
        engine.process(frame(at: 0, x: 0.5, y: 0.05))
        engine.process(frame(at: 0.01, x: 0.545, y: 0.05))
        for index in 0..<6 {
            engine.process(frame(at: 0.02 + Double(index) * 0.01,
                                 x: index.isMultiple(of: 2) ? 0.559 : 0.561, y: 0.05))
        }
        XCTAssertEqual(recorder.bottomTickDirections, [true])
    }

}
