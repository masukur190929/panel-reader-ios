import Foundation

// Original integration contract. No Kotatsu code or remote catalogue is included.
// Website browsing is implemented separately with WebKit. A concrete provider
// is still required for a native catalogue, chapter lists and page downloads.
struct CatalogueTitle: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let coverURL: URL?
    let description: String?
}

struct CatalogueChapter: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let number: Double?
}

struct CataloguePage: Codable, Sendable {
    let imageURL: URL
    let index: Int
}

protocol MangaSource: Sendable {
    var id: String { get }
    var name: String { get }
    var termsURL: URL { get }
    func search(_ query: String) async throws -> [CatalogueTitle]
    func chapters(for titleID: String) async throws -> [CatalogueChapter]
    func pages(for chapterID: String) async throws -> [CataloguePage]
}
