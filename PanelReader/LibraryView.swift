import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var query = ""
    @State private var favouritesOnly = false
    @State private var importing = false
    @State private var selectedBook: Book?
    @State private var removingBook: Book?

    private var filtered: [Book] {
        library.books.filter {
            (!favouritesOnly || $0.isFavourite) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query))
        }.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Library filter", selection: $favouritesOnly) {
                        Text("All books").tag(false)
                        Text("Favourites").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if filtered.isEmpty {
                        ContentUnavailableView {
                            Label(favouritesOnly ? "No favourites yet" : "No books found", systemImage: "books.vertical")
                        } description: {
                            Text(favouritesOnly ? "Tap the heart on a book to save it here." : "Import a PDF or images to start reading.")
                        } actions: {
                            if !favouritesOnly { Button("Import books") { importing = true } }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 26) {
                            ForEach(filtered) { book in
                                Button { selectedBook = book } label: {
                                    BookCard(book: book)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(book.isFavourite ? "Remove favourite" : "Add favourite", systemImage: "heart") {
                                        library.toggleFavourite(id: book.id)
                                    }
                                    Button("Delete book", systemImage: "trash", role: .destructive) { removingBook = book }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Find a book")
            .toolbar {
                Button { importing = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Import books")
            }
            .navigationDestination(item: $selectedBook) { book in BookDetailView(bookID: book.id) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                do { try library.importFiles(result.get()) }
                catch { library.errorMessage = error.localizedDescription }
            }
            .alert("Library message", isPresented: Binding(
                get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } }
            )) {
                Button("OK") { library.errorMessage = nil }
            } message: { Text(library.errorMessage ?? "") }
            .confirmationDialog("Delete this book and its imported files?", isPresented: Binding(
                get: { removingBook != nil }, set: { if !$0 { removingBook = nil } }
            ), titleVisibility: .visible) {
                Button("Delete book", role: .destructive) {
                    if let book = removingBook { library.remove(id: book.id) }
                    removingBook = nil
                }
                Button("Cancel", role: .cancel) { removingBook = nil }
            }
        }
    }
}

struct BookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCover(book: book)
                .aspectRatio(0.68, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .topTrailing) {
                    if book.isFavourite {
                        Image(systemName: "heart.fill").foregroundStyle(.mint)
                            .padding(8).background(.ultraThinMaterial, in: Circle()).padding(8)
                    }
                }
            Text(book.title).font(.headline).lineLimit(2)
            HStack {
                Text("\(book.pageCount) pages")
                Spacer()
                Text(book.kind.label)
            }
            .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: book.progress).tint(.mint)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BookCover: View {
    @EnvironmentObject private var library: LibraryStore
    let book: Book

    private var image: UIImage? {
        guard let url = library.fileURL(for: book) else { return nil }
        if book.kind == .images { return UIImage(contentsOfFile: url.path) }
        if book.kind == .pdf {
            return PDFDocument(url: url)?.page(at: 0)?.thumbnail(of: CGSize(width: 300, height: 440), for: .mediaBox)
        }
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            if book.kind == .demo {
                DemoCover().frame(width: geometry.size.width, height: geometry.size.height)
            } else if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                ZStack {
                    LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "book.closed.fill").font(.system(size: 40)).foregroundStyle(.white)
                }
            }
        }
    }
}

struct BookDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    let bookID: UUID
    @State private var reading = false
    @State private var startPage: Int?

    var body: some View {
        if let book = library.book(id: bookID) {
            ScrollView {
                VStack(spacing: 24) {
                    BookCover(book: book).frame(width: 180, height: 264)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
                    VStack(spacing: 8) {
                        Text(book.title).font(.title.bold()).multilineTextAlignment(.center)
                        Text("\(book.pageCount) pages · \(book.kind.label)").foregroundStyle(.secondary)
                    }
                    Button {
                        startPage = book.currentPage; reading = true
                    } label: {
                        Label(book.lastReadAt == nil ? "Start reading" : "Continue reading", systemImage: "book.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                    if book.lastReadAt != nil {
                        VStack(spacing: 8) {
                            ProgressView(value: book.progress)
                            Text("Page \(book.currentPage + 1) of \(book.pageCount)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !book.bookmarks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bookmarks").font(.headline)
                            ForEach(book.bookmarks, id: \.self) { page in
                                Button("Page \(page + 1)") { startPage = page; reading = true }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }.padding(24)
            }
            .navigationTitle("Book").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { library.toggleFavourite(id: bookID) } label: {
                    Image(systemName: book.isFavourite ? "heart.fill" : "heart")
                }.accessibilityLabel(book.isFavourite ? "Remove favourite" : "Add favourite")
            }
            .fullScreenCover(isPresented: $reading) {
                ReaderView(bookID: bookID, initialPage: startPage ?? book.currentPage)
            }
        } else {
            ContentUnavailableView("Book removed", systemImage: "book.closed")
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var library: LibraryStore
    private var recent: [Book] {
        library.books.filter { $0.lastReadAt != nil }
            .sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recent.isEmpty {
                    ContentUnavailableView("Your next chapter starts here", systemImage: "clock")
                } else {
                    List(recent) { book in
                        NavigationLink { BookDetailView(bookID: book.id) } label: {
                            HStack(spacing: 16) {
                                BookCover(book: book).frame(width: 48, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(book.title).font(.headline)
                                    Text("Page \(book.currentPage + 1) of \(book.pageCount)").font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let date = book.lastReadAt { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }.navigationTitle("History")
        }
    }
}

extension Book: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
