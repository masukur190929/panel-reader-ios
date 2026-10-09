import Foundation
import Combine
import PDFKit
import UIKit

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published var errorMessage: String?

    private let directory: URL
    private var canWrite = true
    private var indexURL: URL { directory.appendingPathComponent("library.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("PanelReader", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: self.directory, withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: indexURL.path) {
                books = try JSONDecoder().decode([Book].self, from: Data(contentsOf: indexURL))
                guard books.allSatisfy({ $0.pageCount > 0 && $0.currentPage >= 0 && $0.currentPage < $0.pageCount }),
                      Set(books.map(\.id)).count == books.count else {
                    throw LibraryError.readOnlyLibrary
                }
            } else {
                books = [.sample]
                try save(books)
            }
        } catch {
            canWrite = false
            errorMessage = LibraryError.readOnlyLibrary.localizedDescription
        }
    }

    func book(id: UUID) -> Book? { books.first { $0.id == id } }

    func fileURL(for book: Book, index: Int = 0) -> URL? {
        guard book.files.indices.contains(index) else { return nil }
        let filename = book.files[index]
        guard !filename.contains("/"), !filename.contains("\\"), filename != ".." else { return nil }
        return directory.appendingPathComponent(book.id.uuidString, isDirectory: true)
            .appendingPathComponent(filename)
    }

    func toggleFavourite(id: UUID) {
        update(id: id) { $0.isFavourite.toggle() }
    }

    func recordPage(id: UUID, page: Int) {
        update(id: id) {
            $0.currentPage = min(max(page, 0), $0.pageCount - 1)
            $0.lastReadAt = Date()
        }
    }

    func toggleBookmark(id: UUID, page: Int) {
        update(id: id) {
            guard (0..<$0.pageCount).contains(page) else { return }
            if $0.bookmarks.contains(page) { $0.bookmarks.removeAll { $0 == page } }
            else { $0.bookmarks.append(page); $0.bookmarks.sort() }
        }
    }

    func remove(id: UUID) {
        guard canWrite else { errorMessage = LibraryError.readOnlyLibrary.localizedDescription; return }
        let updated = books.filter { $0.id != id }
        do {
            try save(updated)
            books = updated
            let files = directory.appendingPathComponent(id.uuidString, isDirectory: true)
            if FileManager.default.fileExists(atPath: files.path) {
                try FileManager.default.removeItem(at: files)
            }
        } catch {
            // Metadata is written before deleting files; failed deletion leaves only unused files.
            errorMessage = error.localizedDescription
        }
    }

    func importFiles(_ urls: [URL]) throws {
        guard canWrite else { throw LibraryError.readOnlyLibrary }
        guard !urls.isEmpty else { return }
        let hasPDF = urls.contains { $0.pathExtension.lowercased() == "pdf" }
        if hasPDF && urls.contains(where: { $0.pathExtension.lowercased() != "pdf" }) {
            throw LibraryError.mixedSelection
        }
        var staged: [Book] = []
        do {
            if hasPDF {
                for url in urls { staged.append(try importPDF(url)) }
            } else {
                staged.append(try importImages(urls))
            }
            let updated = books + staged
            try save(updated)
            books = updated
        } catch {
            for book in staged {
                try? FileManager.default.removeItem(
                    at: directory.appendingPathComponent(book.id.uuidString, isDirectory: true)
                )
            }
            throw error
        }
    }

    private func importPDF(_ url: URL) throws -> Book {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var book = Book(title: url.deletingPathExtension().lastPathComponent, kind: .pdf, pageCount: 1)
        let folder = try createBookDirectory(book.id)
        do {
            let destination = folder.appendingPathComponent("book.pdf")
            try FileManager.default.copyItem(at: url, to: destination)
            guard let pdf = PDFDocument(url: destination), !pdf.isLocked, pdf.pageCount > 0 else {
                throw LibraryError.unreadablePDF
            }
            book.files = ["book.pdf"]
            book.pageCount = pdf.pageCount
            return book
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private func importImages(_ urls: [URL]) throws -> Book {
        let sorted = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        var book = Book(
            title: sorted[0].deletingPathExtension().lastPathComponent,
            kind: .images, pageCount: sorted.count
        )
        let folder = try createBookDirectory(book.id)
        do {
            for (index, url) in sorted.enumerated() {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let name = String(format: "%05d", index) + "." + url.pathExtension.lowercased()
                let destination = folder.appendingPathComponent(name)
                try FileManager.default.copyItem(at: url, to: destination)
                guard UIImage(contentsOfFile: destination.path) != nil else { throw LibraryError.unreadableImage }
                book.files.append(name)
            }
            return book
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private func createBookDirectory(_ id: UUID) throws -> URL {
        let url = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func update(id: UUID, _ mutation: (inout Book) -> Void) {
        guard canWrite else { errorMessage = LibraryError.readOnlyLibrary.localizedDescription; return }
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        var updated = books
        mutation(&updated[index])
        do { try save(updated); books = updated }
        catch { errorMessage = error.localizedDescription }
    }

    private func save(_ records: [Book]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: indexURL, options: .atomic)
    }
}
