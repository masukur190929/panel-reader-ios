import Foundation
import Combine

struct WebSource: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var url: URL
    var lastURL: URL?

    static var initialSources: [WebSource] {
        [WebSource(name: "ManhuaTop", url: URL(string: "https://manhuatop.org/")!),
         WebSource(name: "ManhuaUs", url: URL(string: "https://manhuaus.com/")!)]
    }

    func contains(_ candidate: URL) -> Bool {
        guard let host = url.host?.lowercased(), let other = candidate.host?.lowercased() else { return false }
        let root = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return other == root || other.hasSuffix("." + root)
    }
}

struct WebBookmark: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var url: URL
    var sourceName: String
    var savedAt = Date()
}

enum WebsiteAddress {
    static func parse(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let value = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        return url
    }

    static func isAllowed(_ url: URL) -> Bool {
        parse(url.absoluteString) != nil
    }
}

@MainActor
final class SourceStore: ObservableObject {
    @Published private(set) var sources: [WebSource] = []
    @Published private(set) var bookmarks: [WebBookmark] = []
    @Published var errorMessage: String?
    private let indexURL: URL
    private var canWrite = true

    private struct Records: Codable {
        var sources: [WebSource]
        var bookmarks: [WebBookmark]
    }

    init(directory: URL? = nil, initialSources: [WebSource] = WebSource.initialSources) {
        let directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("PanelReader", isDirectory: true)
        indexURL = directory.appendingPathComponent("web-sources.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let records = try JSONDecoder().decode(Records.self, from: Data(contentsOf: indexURL))
                guard records.sources.allSatisfy({ WebsiteAddress.isAllowed($0.url) && ($0.lastURL.map(WebsiteAddress.isAllowed) ?? true) }),
                      records.bookmarks.allSatisfy({ WebsiteAddress.isAllowed($0.url) }),
                      Set(records.sources.map(\.id)).count == records.sources.count,
                      Set(records.bookmarks.map(\.id)).count == records.bookmarks.count else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                sources = records.sources
                bookmarks = records.bookmarks
            } else {
                sources = initialSources
                try persist(sources: sources, bookmarks: [])
            }
        } catch {
            canWrite = false
            errorMessage = "Your saved sources could not be loaded. The saved file has been preserved."
        }
    }

    @discardableResult
    func saveSource(id: UUID? = nil, name: String, address: String) -> Bool {
        guard let url = WebsiteAddress.parse(address) else {
            errorMessage = "Enter a valid HTTPS website address without a username or password."
            return false
        }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = sources
        if let id, let index = updated.firstIndex(where: { $0.id == id }) {
            updated[index].name = title.isEmpty ? (url.host ?? "Website") : title
            if updated[index].url != url { updated[index].lastURL = nil }
            updated[index].url = url
        } else {
            updated.append(WebSource(name: title.isEmpty ? (url.host ?? "Website") : title, url: url))
        }
        return commit(sources: updated, bookmarks: bookmarks)
    }

    func removeSource(id: UUID) {
        commit(sources: sources.filter { $0.id != id }, bookmarks: bookmarks)
    }

    func recordVisit(sourceID: UUID, url: URL) {
        guard WebsiteAddress.isAllowed(url), let index = sources.firstIndex(where: { $0.id == sourceID }),
              sources[index].contains(url), sources[index].lastURL != url else { return }
        var updated = sources
        updated[index].lastURL = url
        commit(sources: updated, bookmarks: bookmarks)
    }

    func isBookmarked(_ url: URL) -> Bool { bookmarks.contains { $0.url == url } }

    func toggleBookmark(url: URL, title: String, sourceName: String) {
        guard WebsiteAddress.isAllowed(url) else { return }
        var updated = bookmarks
        if let index = updated.firstIndex(where: { $0.url == url }) {
            updated.remove(at: index)
        } else {
            updated.insert(WebBookmark(title: title.isEmpty ? (url.host ?? "Web page") : title,
                                       url: url, sourceName: sourceName), at: 0)
        }
        commit(sources: sources, bookmarks: updated)
    }

    func removeBookmark(id: UUID) {
        commit(sources: sources, bookmarks: bookmarks.filter { $0.id != id })
    }

    @discardableResult
    private func commit(sources: [WebSource], bookmarks: [WebBookmark]) -> Bool {
        guard canWrite else { errorMessage = "Saved sources are read-only until the saved file is restored."; return false }
        do {
            try persist(sources: sources, bookmarks: bookmarks)
            self.sources = sources
            self.bookmarks = bookmarks
            return true
        } catch {
            errorMessage = "Could not save your sources: " + error.localizedDescription
            return false
        }
    }

    private func persist(sources: [WebSource], bookmarks: [WebBookmark]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Records(sources: sources, bookmarks: bookmarks)).write(to: indexURL, options: .atomic)
    }
}
