import XCTest

final class ReaderFlowTests: XCTestCase {
    @MainActor
    func testSampleCanBeReadBookmarkedAndFoundInHistory() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let sample = app.buttons["sample-book"]
        XCTAssertTrue(sample.waitForExistence(timeout: 15))
        saveScreenshot(app, named: "Library")
        sample.tap()

        let startReading = app.buttons["Start reading"]
        XCTAssertTrue(startReading.waitForExistence(timeout: 5))
        saveScreenshot(app, named: "Book details")
        startReading.tap()

        let closeReader = app.buttons["Close reader"]
        XCTAssertTrue(closeReader.waitForExistence(timeout: 5))
        app.buttons["Bookmark page"].tap()
        XCTAssertTrue(app.buttons["Remove bookmark"].exists)
        saveScreenshot(app, named: "Reader")
        closeReader.tap()

        XCTAssertTrue(app.buttons["Page 1"].waitForExistence(timeout: 5))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Night Train"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot(app, named: "History")
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
