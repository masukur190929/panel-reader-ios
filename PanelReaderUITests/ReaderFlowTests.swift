import XCTest

final class ReaderFlowTests: XCTestCase {
    @MainActor
    func testSampleCanBeReadBookmarkedAndFoundInHistory() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
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
    func testPageButtonsBookmarkJumpAndRightToLeftSwipes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["sample-book"].waitForExistence(timeout: 15))
        app.buttons["sample-book"].tap()
        app.buttons["Start reading"].tap()

        let progress = app.staticTexts["reading-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "1 / 6")
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
        app.buttons["Next page"].tap()
        expectPage("2 / 6", progress: progress)
        app.buttons["Bookmark page"].tap()
        app.buttons["Next page"].tap()
        expectPage("3 / 6", progress: progress)
        app.buttons["Saved bookmarks"].tap()
        app.buttons["Jump to page 2"].tap()
        expectPage("2 / 6", progress: progress)

        app.buttons["Reading settings"].tap()
        app.buttons["Horizontal pages"].tap()
        app.buttons["Reading settings"].tap()
        app.buttons["Right to left"].tap()
        XCTAssertEqual(app.buttons["Reading settings"].value as? String, "Right to left")
        app.swipeRight()
        expectPage("3 / 6", progress: progress)
        app.swipeLeft()
        expectPage("2 / 6", progress: progress)
        saveScreenshot(app, named: "Right-to-left reader")

        app.buttons["Reading settings"].tap()
        app.buttons["Vertical scrolling"].tap()
        expectPage("2 / 6", progress: progress)
        app.buttons["Close reader"].tap()
        XCTAssertTrue(app.buttons["Continue reading"].waitForExistence(timeout: 5))
        app.buttons["Continue reading"].tap()
        expectPage("2 / 6", progress: progress)
    }

    @MainActor
    private func expectPage(_ text: String, progress: XCUIElement) {
        let predicate = NSPredicate(format: "label == %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    @MainActor
    private func saveScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
