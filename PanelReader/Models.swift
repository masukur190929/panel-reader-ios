import Foundation

enum BookKind: String, Codable {
    case pdf, images, demo

    var label: String {
        switch self {
        case .pdf: "PDF"
        case .images: "Images"
        case .demo: "Sample"
        }
    }
}

struct Book: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var kind: BookKind
    var files: [String] = []
    var pageCount: Int
    var currentPage = 0
    var bookmarks: [Int] = []
    var isFavourite = false
    var addedAt = Date()
    var lastReadAt: Date?

    var progress: Double {
        guard lastReadAt != nil, pageCount > 0 else { return 0 }
        return Double(currentPage + 1) / Double(pageCount)
    }

    static var sample: Book {
        Book(title: "Night Train", kind: .demo, pageCount: 6)
    }
}

enum LibraryError: LocalizedError {
    case unsupportedFile, unreadablePDF, unreadableImage, mixedSelection
    case readOnlyLibrary

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Choose a PDF or image files. CBZ and CBR archives are not supported in this version."
        case .unreadablePDF:
            "This PDF could not be opened. It may be damaged or password protected."
        case .unreadableImage:
            "One of the selected images could not be opened."
        case .mixedSelection:
            "Import PDFs separately from images. Select several images together to create one book."
        case .readOnlyLibrary:
            "Your saved library could not be loaded. Its files have been preserved. Close the app and restore the library before making changes."
        }
    }
}
