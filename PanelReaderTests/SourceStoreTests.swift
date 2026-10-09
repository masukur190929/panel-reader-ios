import XCTest
@testable import PanelReader

final class SourceStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testWebsiteAddressesRejectUnsupportedSchemesAndCredentials() throws {
        XCTAssertEqual(WebsiteAddress.parse(" example.com/comics ")?.absoluteString, "https://example.com/comics")
        XCTAssertNotNil(WebsiteAddress.parse("https://example.com/search?q=night%20train"))
        for invalid in ["", "https://", "http://example.com", "file:///etc/passwd", "javascript:alert(1)",
                        "data:text/html,hello", "https://user:password@example.com", "https://example.com/line break"] {
            XCTAssertNil(WebsiteAddress.parse(invalid), invalid)
        }
    }

    @MainActor
    func testWebBookmarksAndResumeSurviveRestartWithoutSavingExternalAdVisit() throws {
        let directory = try temporaryDirectory()
        let store = SourceStore(directory: directory, initialSources: [])
        XCTAssertTrue(store.saveSource(name: "My comics", address: "https://example.com/"))
        let source = try XCTUnwrap(store.sources.first)
        let chapter = try XCTUnwrap(URL(string: "https://example.com/series/night-train/chapter-2"))
        store.recordVisit(sourceID: source.id, url: chapter)
        store.recordVisit(sourceID: source.id, url: URL(string: "https://example.com.advertiser.invalid/")!)
        store.toggleBookmark(url: chapter, title: "Night Train · Chapter 2", sourceName: source.name)

        let reopened = SourceStore(directory: directory, initialSources: [])
        XCTAssertEqual(reopened.sources.first?.lastURL, chapter)
        XCTAssertEqual(reopened.bookmarks.first?.title, "Night Train · Chapter 2")
        XCTAssertTrue(reopened.isBookmarked(chapter))
        reopened.removeSource(id: source.id)
        XCTAssertTrue(reopened.sources.isEmpty)
        XCTAssertEqual(reopened.bookmarks.count, 1, "Saved pages remain usable after removing a website shortcut")
        reopened.toggleBookmark(url: chapter, title: "Night Train · Chapter 2", sourceName: source.name)
        XCTAssertTrue(reopened.bookmarks.isEmpty)
        XCTAssertTrue(SourceStore(directory: directory, initialSources: []).bookmarks.isEmpty)
    }

    @MainActor
    func testDamagedSavedSourcesArePreserved() throws {
        let directory = try temporaryDirectory()
        let index = directory.appendingPathComponent("web-sources.json")
        let original = Data("damaged saved sources".utf8)
        try original.write(to: index)
        let store = SourceStore(directory: directory)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.saveSource(name: "New website", address: "https://example.com"))
        XCTAssertEqual(try Data(contentsOf: index), original)
    }
}
