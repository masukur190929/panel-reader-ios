import XCTest
import UIKit
@testable import PanelReader

final class LibraryStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testPDFImportAndReadingStateSurviveRestart() throws {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("Three chapters.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 150))
        try renderer.pdfData { context in
            for _ in 0..<3 { context.beginPage() }
        }.write(to: source)
        let libraryDirectory = root.appendingPathComponent("library")
        let store = LibraryStore(directory: libraryDirectory)
        try store.importFiles([source])
        let book = try XCTUnwrap(store.books.last)
        XCTAssertEqual(book.pageCount, 3)
        store.recordPage(id: book.id, page: 99)
        store.toggleFavourite(id: book.id)
        store.toggleBookmark(id: book.id, page: 1)
        try FileManager.default.removeItem(at: source)

        let reopened = LibraryStore(directory: libraryDirectory)
        let persisted = try XCTUnwrap(reopened.book(id: book.id))
        XCTAssertEqual(persisted.currentPage, 2)
        XCTAssertTrue(persisted.isFavourite)
        XCTAssertEqual(persisted.bookmarks, [1])
        XCTAssertNotNil(persisted.lastReadAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(reopened.fileURL(for: persisted)).path))
    }

    @MainActor
    func testFailedBatchDoesNotLeavePartiallyImportedBooks() throws {
        let root = try temporaryDirectory()
        let valid = root.appendingPathComponent("Valid.pdf")
        let invalid = root.appendingPathComponent("Invalid.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 150))
        try renderer.pdfData { $0.beginPage() }.write(to: valid)
        try Data("Not a PDF".utf8).write(to: invalid)
        let libraryDirectory = root.appendingPathComponent("library")
        let store = LibraryStore(directory: libraryDirectory)
        let count = store.books.count
        XCTAssertThrowsError(try store.importFiles([valid, invalid]))
        XCTAssertEqual(store.books.count, count)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: libraryDirectory.path)
        XCTAssertEqual(remaining, ["library.json"])
    }

    @MainActor
    func testCorruptLibraryIsPreserved() throws {
        let root = try temporaryDirectory()
        let index = root.appendingPathComponent("library.json")
        let original = Data("broken library data".utf8)
        try original.write(to: index)
        let store = LibraryStore(directory: root)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.importFiles([root.appendingPathComponent("book.pdf")]))
        XCTAssertEqual(try Data(contentsOf: index), original)
    }

    @MainActor
    func testImagePagesUseNaturalFilenameOrder() throws {
        let root = try temporaryDirectory()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
        let data = try XCTUnwrap(image.pngData())
        let second = root.appendingPathComponent("page2.png")
        let tenth = root.appendingPathComponent("page10.png")
        try data.write(to: second); try data.write(to: tenth)
        let store = LibraryStore(directory: root.appendingPathComponent("library"))
        try store.importFiles([tenth, second])
        let book = try XCTUnwrap(store.books.last)
        XCTAssertEqual(book.title, "page2")
        XCTAssertEqual(book.files, ["00000.png", "00001.png"])
        XCTAssertEqual(book.pageCount, 2)
    }
}
