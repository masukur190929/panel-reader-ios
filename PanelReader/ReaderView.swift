import SwiftUI
import PDFKit

struct ReaderView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readerMode") private var mode = "vertical"
    @AppStorage("readingRightToLeft") private var rightToLeft = false
    let bookID: UUID
    @State private var page: Int
    @State private var visiblePage: Int?

    init(bookID: UUID, initialPage: Int) {
        self.bookID = bookID
        _page = State(initialValue: initialPage)
        _visiblePage = State(initialValue: initialPage)
    }

    var body: some View {
        if let book = library.book(id: bookID) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close reader")
                    Text(book.title).font(.headline).lineLimit(1)
                    Spacer()
                    Button { library.toggleBookmark(id: bookID, page: page) } label: {
                        Image(systemName: book.bookmarks.contains(page) ? "bookmark.fill" : "bookmark")
                    }.accessibilityLabel(book.bookmarks.contains(page) ? "Remove bookmark" : "Bookmark page")
                    Menu {
                        if book.bookmarks.isEmpty {
                            Text("No bookmarks yet")
                        } else {
                            ForEach(book.bookmarks, id: \.self) { savedPage in
                                Button("Jump to page \(savedPage + 1)") { go(to: savedPage, in: book) }
                            }
                        }
                    } label: { Image(systemName: "list.bullet") }
                        .accessibilityLabel("Saved bookmarks")
                    Menu {
                        Button("Vertical scrolling", systemImage: mode == "vertical" ? "checkmark" : "arrow.up.arrow.down") { mode = "vertical" }
                        Button("Horizontal pages", systemImage: mode == "horizontal" ? "checkmark" : "arrow.left.arrow.right") { mode = "horizontal" }
                        Divider()
                        Button("Left to right", systemImage: rightToLeft ? "arrow.right" : "checkmark") { rightToLeft = false }
                        Button("Right to left", systemImage: rightToLeft ? "checkmark" : "arrow.left") { rightToLeft = true }
                    } label: { Image(systemName: "rectangle.split.2x1") }
                        .accessibilityLabel("Reading settings")
                        .accessibilityValue(rightToLeft ? "Right to left" : "Left to right")
                }.padding(18).background(Color(white: 0.08))

                if book.kind == .pdf, let url = library.fileURL(for: book) {
                    PDFReader(url: url, page: $page, vertical: mode == "vertical", rightToLeft: rightToLeft)
                } else if book.kind == .pdf {
                    ContentUnavailableView("File unavailable", systemImage: "doc.badge.ellipsis")
                } else if mode == "horizontal" {
                    TabView(selection: $page) {
                        ForEach(rightToLeft ? Array((0..<book.pageCount).reversed()) : Array(0..<book.pageCount), id: \.self) { index in
                            ReaderPage(book: book, index: index).tag(index)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                        .environment(\.layoutDirection, .leftToRight)
                        .id(rightToLeft)
                } else {
                    GeometryReader { geometry in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(0..<book.pageCount, id: \.self) { index in
                                    ReaderPage(book: book, index: index)
                                        .frame(height: geometry.size.width * 1.45).id(index)
                                }
                            }.scrollTargetLayout()
                        }
                        .scrollPosition(id: $visiblePage, anchor: .top)
                    }
                }

                HStack(spacing: 16) {
                    Button { go(to: page - 1, in: book) } label: {
                        Image(systemName: rightToLeft && mode == "horizontal" ? "chevron.right" : "chevron.left")
                    }.accessibilityLabel("Previous page").disabled(page == 0)
                    Text("\(page + 1) / \(book.pageCount)").font(.caption.monospacedDigit())
                        .frame(minWidth: 54)
                        .accessibilityIdentifier("reading-progress")
                    if book.pageCount > 1 {
                        Slider(value: Binding(
                            get: { Double(page) },
                            set: { go(to: Int($0), in: book) }
                        ), in: 0...Double(book.pageCount - 1), step: 1)
                        .accessibilityLabel("Reading page")
                    }
                    Button { go(to: page + 1, in: book) } label: {
                        Image(systemName: rightToLeft && mode == "horizontal" ? "chevron.left" : "chevron.right")
                    }.accessibilityLabel("Next page").disabled(page == book.pageCount - 1)
                }.padding(18).background(Color(white: 0.08))
            }
            .background(.black).preferredColorScheme(.dark)
            .onAppear { library.recordPage(id: bookID, page: page) }
            .onChange(of: page) { _, newPage in
                library.recordPage(id: bookID, page: newPage)
            }
            .onChange(of: visiblePage) { _, newPage in
                if mode == "vertical", book.kind != .pdf, let newPage { page = newPage }
            }
            .onChange(of: mode) { _, _ in visiblePage = page }
        } else {
            Button("Close reader") { dismiss() }
        }
    }

    private func go(to target: Int, in book: Book) {
        let destination = min(max(target, 0), book.pageCount - 1)
        page = destination
        visiblePage = destination
    }
}

struct ReaderPage: View {
    @EnvironmentObject private var library: LibraryStore
    let book: Book
    let index: Int
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        Group {
            if book.kind == .demo {
                DemoPage(index: index)
            } else if let url = library.fileURL(for: book, index: index),
                      let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ContentUnavailableView("Page unavailable", systemImage: "photo")
            }
        }
        .scaleEffect(scale * magnification)
        .gesture(MagnifyGesture()
            .updating($magnification) { value, state, _ in state = value.magnification }
            .onEnded { value in scale = min(max(scale * value.magnification, 1), 3) })
        .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2 } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityLabel("Page \(index + 1)")
    }
}

struct PDFReader: UIViewRepresentable {
    let url: URL
    @Binding var page: Int
    let vertical: Bool
    let rightToLeft: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.backgroundColor = .black
        view.autoScales = true
        configure(view)
        if let initial = view.document?.page(at: page) { view.go(to: initial) }
        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged, object: view, queue: .main
        ) { [weak coordinator = context.coordinator, weak view] _ in
            guard let coordinator, let view, let current = view.currentPage,
                  let index = view.document?.index(for: current), index != NSNotFound else { return }
            // Defer the state write so PDFKit never changes SwiftUI state during an update.
            DispatchQueue.main.async {
                guard let latest = view.currentPage,
                      view.document?.index(for: latest) == index else { return }
                coordinator.parent.page = index
            }
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if view.displayDirection != (vertical ? .vertical : .horizontal) || view.displaysRTL != rightToLeft {
            configure(view)
        }
        let current = view.currentPage.flatMap { view.document?.index(for: $0) }
        if current != page, let target = view.document?.page(at: page) { view.go(to: target) }
    }

    private func configure(_ view: PDFView) {
        view.displayDirection = vertical ? .vertical : .horizontal
        view.displaysRTL = rightToLeft
        view.displayMode = vertical ? .singlePageContinuous : .singlePage
        view.usePageViewController(!vertical, withViewOptions: nil)
        view.autoScales = true
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) }
        coordinator.observer = nil
    }

    final class Coordinator {
        var parent: PDFReader
        var observer: NSObjectProtocol?
        init(parent: PDFReader) { self.parent = parent }
    }
}
