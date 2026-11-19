import Foundation
import CoreGraphics
import XCTest
@testable import SlideSenseCore

final class ShortcutTests: XCTestCase {
    func testDefaultAndInvalidShortcuts() {
        var shortcut = ShortcutConfiguration()
        XCTAssertTrue(shortcut.isValid)
        XCTAssertEqual(shortcut.keyCode, 20)
        XCTAssertTrue(shortcut.command && shortcut.shift)
        shortcut.keyCode = 65535
        XCTAssertFalse(shortcut.isValid)
        shortcut.keyCode = 20
        shortcut.command = false
        shortcut.shift = false
        XCTAssertFalse(shortcut.isValid)
    }

    func testOldScreenshotSettingsMigrateToNativeShortcut() throws {
        let json = #"{"bottomEdgeAction":"screenshot","screenshotFolder":"/tmp/OldFolder"}"#
        let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.bottomEdgeAction, .shortcut)
        XCTAssertEqual(settings.bottomShortcut, ShortcutConfiguration())
    }
    func testShortcutProducesMatchingPressAndRelease() {
        var shortcut = ShortcutConfiguration()
        shortcut.keyCode = 8
        shortcut.shift = false
        shortcut.control = true
        let events = MediaKeyController.shortcutEvents(shortcut)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.map { $0.type }, [.keyDown, .keyUp])
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 8)
            XCTAssertEqual(event.flags, [.maskCommand, .maskControl])
        }
        shortcut.keyCode = 65535
        XCTAssertTrue(MediaKeyController.shortcutEvents(shortcut).isEmpty)
    }

    func testAllPresetsProduceValidEvents() {
        for preset in ShortcutConfiguration.presets {
            XCTAssertTrue(preset.shortcut.isValid, preset.name)
            XCTAssertEqual(MediaKeyController.shortcutEvents(preset.shortcut).count, 2, preset.name)
        }
        XCTAssertEqual(ShortcutConfiguration().displayName, "⇧⌘3")
    }

}
