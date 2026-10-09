import SwiftUI

struct BrowserDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    var sourceID: UUID?
}

struct SourcesView: View {
    @EnvironmentObject private var store: SourceStore
    @State private var query = ""
    @State private var bookmarksOnly = false
    @State private var destination: BrowserDestination?
    @State private var editing: WebSource?
    @State private var showingEditor = false
    @State private var removing: WebSource?

    private var sources: [WebSource] {
        store.sources.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.url.absoluteString.localizedCaseInsensitiveContains(query) }
    }

    private var bookmarks: [WebBookmark] {
        store.bookmarks.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.sourceName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your next chapter").font(.title2.bold())
                        Text("Browse your websites and save a page to return to it later.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Picker("Source filter", selection: $bookmarksOnly) {
                        Text("Websites").tag(false)
                        Text("Saved pages").tag(true)
                    }.pickerStyle(.segmented)

                    if bookmarksOnly {
                        if bookmarks.isEmpty {
                            ContentUnavailableView("No saved pages", systemImage: "bookmark", description: Text("Tap the bookmark while browsing to save a page here."))
                        } else {
                            ForEach(bookmarks) { bookmark in
                                Button {
                                    destination = BrowserDestination(title: bookmark.sourceName, url: bookmark.url)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "bookmark.fill").foregroundStyle(.mint)
                                            .frame(width: 44, height: 44).background(.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(bookmark.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                            Text(bookmark.sourceName).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Remove saved page", systemImage: "trash", role: .destructive) { store.removeBookmark(id: bookmark.id) }
                                    }
                            }
                        }
                    } else {
                        if sources.isEmpty {
                            ContentUnavailableView {
                                Label("No websites found", systemImage: "globe")
                            } description: {
                                Text("Add a website to start browsing.")
                            } actions: {
                                Button("Add website") { editing = nil; showingEditor = true }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                                ForEach(sources) { source in
                                    Button {
                                        destination = BrowserDestination(title: source.name, url: source.lastURL ?? source.url, sourceID: source.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack {
                                                Text(String(source.name.prefix(1))).font(.title.bold()).foregroundStyle(.mint)
                                                    .frame(width: 54, height: 54).background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                                                Spacer()
                                                Image(systemName: "arrow.up.right").font(.subheadline).foregroundStyle(.secondary)
                                            }
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(source.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                                                Text(source.url.host ?? "Website").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                            Label(source.lastURL == nil ? "Open website" : "Continue browsing", systemImage: "globe")
                                                .font(.caption).foregroundStyle(.mint)
                                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
                                    }.buttonStyle(.plain)
                                        .accessibilityIdentifier("source-" + source.name)
                                        .contextMenu {
                                            Button("Open homepage", systemImage: "house") {
                                                destination = BrowserDestination(title: source.name, url: source.url, sourceID: source.id)
                                            }
                                            Button("Edit website", systemImage: "pencil") { editing = source; showingEditor = true }
                                            Button("Remove website", systemImage: "trash", role: .destructive) { removing = source }
                                        }
                                }
                            }
                        }
                        Text("Websites provide their own search and reading controls. Their privacy policies apply when you visit.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }
            .navigationTitle("Sources")
            .searchable(text: $query, prompt: "Find a website or saved page")
            .toolbar {
                Button { editing = nil; showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add website")
            }
            .sheet(isPresented: $showingEditor) { SourceEditor(source: editing).environmentObject(store) }
            .fullScreenCover(item: $destination) { item in
                SourceBrowser(destination: item).environmentObject(store)
            }
            .alert("Sources message", isPresented: Binding(
                get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .confirmationDialog("Remove this website?", isPresented: Binding(
                get: { removing != nil }, set: { if !$0 { removing = nil } }
            ), titleVisibility: .visible) {
                Button("Remove website", role: .destructive) {
                    if let removing { store.removeSource(id: removing.id) }
                    removing = nil
                }
                Button("Cancel", role: .cancel) { removing = nil }
            }
        }
    }
}

private struct SourceEditor: View {
    @EnvironmentObject private var store: SourceStore
    @Environment(\.dismiss) private var dismiss
    let source: WebSource?
    @State private var name: String
    @State private var address: String
    @State private var message: String?

    init(source: WebSource?) {
        self.source = source
        _name = State(initialValue: source?.name ?? "")
        _address = State(initialValue: source?.url.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Website name", text: $name).textInputAutocapitalization(.words)
                    TextField("Website address", text: $address).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("website-address")
                } footer: {
                    Text("Use an HTTPS address, for example https://example.com.")
                }
                if let message { Text(message).foregroundStyle(.red) }
            }
            .navigationTitle(source == nil ? "Add website" : "Edit website")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save website") {
                        if store.saveSource(id: source?.id, name: name, address: address) {
                            dismiss()
                        } else {
                            message = store.errorMessage
                            store.errorMessage = nil
                        }
                    }.disabled(WebsiteAddress.parse(address) == nil)
                }
            }
        }
    }
}
