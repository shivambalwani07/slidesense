import Foundation
import XCTest
@testable import SlideSenseCore

final class ScreenshotTests: XCTestCase {
    func testFolderPreferenceAndTildeExpansion() {
        XCTAssertEqual(ScreenshotController.folderURL(customPath: "/tmp/Chosen", systemPath: "/tmp/System").path, "/tmp/Chosen")
        XCTAssertEqual(ScreenshotController.folderURL(customPath: nil, systemPath: "~/Desktop/screenshot").path,
                       FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/screenshot").path)
        XCTAssertEqual(ScreenshotController.folderURL(customPath: nil, systemPath: nil).lastPathComponent, "Desktop")
    }
}
