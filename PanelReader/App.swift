import SwiftUI

@main
struct PanelReaderApp: App {
    @StateObject private var library: LibraryStore
    @AppStorage("darkAppearance") private var darkAppearance = true

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            // Keep every simulator UI test independent of previous test launches.
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PanelReaderUITests-" + UUID().uuidString, isDirectory: true)
            _library = StateObject(wrappedValue: LibraryStore(directory: directory))
            UserDefaults.standard.removeObject(forKey: "readerMode")
            UserDefaults.standard.removeObject(forKey: "readingRightToLeft")
            return
        }
        #endif
        _library = StateObject(wrappedValue: LibraryStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .tint(.mint)
                .preferredColorScheme(darkAppearance ? .dark : nil)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
    }
}

struct SettingsView: View {
    @AppStorage("darkAppearance") private var darkAppearance = true
    @AppStorage("readerMode") private var readerMode = "vertical"
    @AppStorage("readingRightToLeft") private var rightToLeft = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    Picker("Default layout", selection: $readerMode) {
                        Text("Vertical scrolling").tag("vertical")
                        Text("Horizontal pages").tag("horizontal")
                    }
                    Toggle("Right-to-left pages", isOn: $rightToLeft)
                    Text("In horizontal mode, swipe left to go back and right to read the next page when right-to-left is enabled.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Dark appearance", isOn: $darkAppearance)
                }
                Section("Your library") {
                    Text("Imported files, favourites, bookmarks and reading progress stay on this device.")
                    Text("Import PDF files, or select several images to create a book. Images are ordered by filename.")
                }
                Section("About") {
                    LabeledContent("Panel Reader", value: "0.1.0")
                    Text("An independent reader for iPhone and iPad.")
                    Text("The Night Train sample is original demonstration content included with this project.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
