import XCTest

final class ReaderFlowTests: XCTestCase {
    @MainActor
    func testSourcesOpenNavigateSaveAndReopenWebPages() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-offline-web-fixtures"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sources"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Sources"].tap()
        let source = app.buttons["source-ManhuaTop"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["source-ManhuaUs"].exists)
        saveScreenshot(app, named: "Sources")
        source.tap()

        XCTAssertTrue(app.webViews.staticTexts["Chapter 1"].waitForExistence(timeout: 15))
        let nextChapter = app.links["Continue to chapter 2"]
        XCTAssertTrue(nextChapter.waitForExistence(timeout: 5))
        nextChapter.tap()
        XCTAssertTrue(app.webViews.staticTexts["Chapter 2"].waitForExistence(timeout: 10))
        let bookmark = app.buttons["Bookmark web page"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: bookmark)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        bookmark.tap()
        XCTAssertTrue(app.buttons["Remove web bookmark"].exists)
        saveScreenshot(app, named: "Website browser - offline fixture")
        app.buttons["Close website"].tap()

        app.buttons["Saved pages"].tap()
        let savedPage = app.buttons.containing(.staticText, identifier: "Night Train · Chapter 2 (preview)").firstMatch
        XCTAssertTrue(savedPage.waitForExistence(timeout: 5))
        saveScreenshot(app, named: "Saved web pages")
        savedPage.tap()
        XCTAssertTrue(app.webViews.staticTexts["Chapter 2"].waitForExistence(timeout: 10))
        app.buttons["Remove web bookmark"].tap()
        app.buttons["Close website"].tap()
        XCTAssertTrue(app.staticTexts["No saved pages"].waitForExistence(timeout: 5))

        app.buttons["Websites"].tap()
        app.buttons["Add website"].tap()
        app.textFields["Website name"].tap()
        app.textFields["Website name"].typeText("My reading site")
        app.textFields["website-address"].tap()
        app.textFields["website-address"].typeText("https://reader-preview.invalid/")
        app.buttons["Save website"].tap()
        XCTAssertTrue(app.buttons["source-My reading site"].waitForExistence(timeout: 5))
    }

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
