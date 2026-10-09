import SwiftUI
import WebKit
import Combine

@MainActor
struct SourceBrowser: View {
    @EnvironmentObject private var store: SourceStore
    @Environment(\.dismiss) private var dismiss
    let destination: BrowserDestination
    @StateObject private var session: BrowserSession

    init(destination: BrowserDestination) {
        self.destination = destination
        _session = StateObject(wrappedValue: BrowserSession(initialURL: destination.url))
    }

    private var homeURL: URL {
        if let source = store.sources.first(where: { $0.id == destination.sourceID }) { return source.url }
        var components = URLComponents(url: destination.url, resolvingAgainstBaseURL: false)
        components?.path = "/"
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? destination.url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if session.isLoading { ProgressView(value: session.progress).tint(.mint) }
                if let message = session.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                        Text(message).font(.footnote)
                        Spacer()
                        Button("Retry") { session.reload() }
                    }.padding().background(.regularMaterial)
                }
                BrowserWebView(session: session)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { session.stop(); dismiss() }.accessibilityLabel("Close website")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(destination.title).font(.headline).lineLimit(1)
                        Text(session.url.host ?? "Website").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        store.toggleBookmark(url: session.url, title: session.title, sourceName: destination.title)
                    } label: {
                        Image(systemName: store.isBookmarked(session.url) ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(store.isBookmarked(session.url) ? "Remove web bookmark" : "Bookmark web page")
                    .disabled(!session.hasLoadedPage || session.isLoading || session.errorMessage != nil)
                    ShareLink(item: session.url) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share web page")
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 20) {
                    Button { session.goBack() } label: { Image(systemName: "chevron.left").frame(width: 36, height: 44) }
                        .disabled(!session.canGoBack).accessibilityLabel("Previous web page")
                    Button { session.goForward() } label: { Image(systemName: "chevron.right").frame(width: 36, height: 44) }
                        .disabled(!session.canGoForward).accessibilityLabel("Next web page")
                    Spacer(minLength: 0)
                    Label("Private session", systemImage: "lock").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { session.load(homeURL) } label: { Image(systemName: "house").frame(width: 36, height: 44) }
                        .accessibilityLabel("Website homepage")
                    Button { session.isLoading ? session.stop() : session.reload() } label: {
                        Image(systemName: session.isLoading ? "xmark" : "arrow.clockwise").frame(width: 36, height: 44)
                    }.accessibilityLabel(session.isLoading ? "Stop loading website" : "Reload website")
                }.padding(.horizontal, 12).background(.regularMaterial)
            }
            .onAppear {
                session.onVisit = { url in
                    if let id = destination.sourceID { store.recordVisit(sourceID: id, url: url) }
                }
                session.start()
            }
            .onDisappear { session.close() }
        }
    }
}

private struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var session: BrowserSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var url: URL
    @Published private(set) var title = ""
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var hasLoadedPage = false
    @Published private(set) var errorMessage: String?
    let webView: WKWebView
    var onVisit: ((URL) -> Void)?
    private var started = false
    private var observations: [NSKeyValueObservation] = []

    #if DEBUG
    private var previewHistory: [URL] = []
    private var previewIndex = -1
    private var previewsEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-offline-web-fixtures") }
    #endif

    init(initialURL: URL) {
        url = initialURL
        let configuration = WKWebViewConfiguration()
        // Cookies and website storage last only for this browser session.
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        for keyPath in [\WKWebView.isLoading, \WKWebView.canGoBack, \WKWebView.canGoForward] {
            observations.append(webView.observe(keyPath, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updateState() }
            })
        }
        observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateState() }
        })
        observations.append(webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateState() }
        })
        observations.append(webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateState() }
        })
    }

    func start() {
        guard !started else { return }
        started = true
        load(url)
    }

    func load(_ address: URL) {
        guard WebsiteAddress.isAllowed(address) else { errorMessage = "This browser opens HTTPS webpages."; return }
        errorMessage = nil
        hasLoadedPage = false
        url = address
        #if DEBUG
        if previewsEnabled { loadPreview(address); return }
        #endif
        webView.load(URLRequest(url: address, timeoutInterval: 45))
    }

    func goBack() {
        #if DEBUG
        if previewsEnabled {
            guard previewIndex > 0 else { return }
            previewIndex -= 1
            loadPreview(previewHistory[previewIndex], recording: false)
            return
        }
        #endif
        webView.goBack()
    }

    func goForward() {
        #if DEBUG
        if previewsEnabled {
            guard previewIndex + 1 < previewHistory.count else { return }
            previewIndex += 1
            loadPreview(previewHistory[previewIndex], recording: false)
            return
        }
        #endif
        webView.goForward()
    }

    func reload() {
        errorMessage = nil
        #if DEBUG
        if previewsEnabled { loadPreview(url, recording: false); return }
        #endif
        if webView.url == nil { load(url) } else { webView.reload() }
    }

    func stop() { webView.stopLoading(); isLoading = false }

    func close() {
        stop()
        onVisit = nil
        observations.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast,
            completionHandler: {}
        )
    }

    private func updateState() {
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        title = webView.title ?? ""
        #if DEBUG
        if previewsEnabled {
            canGoBack = previewIndex > 0
            canGoForward = previewIndex + 1 < previewHistory.count
            return
        }
        #endif
        if let address = webView.url, WebsiteAddress.isAllowed(address) { url = address }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorMessage = nil
        hasLoadedPage = false
        updateState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateState()
        hasLoadedPage = true
        onVisit?(url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { show(error) }

    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        updateState()
        errorMessage = "The page could not be loaded. " + error.localizedDescription
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isLoading = false
        errorMessage = "The website stopped responding. Reload to continue."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let address = navigationAction.request.url else { decisionHandler(.cancel); return }
        if address.scheme == "about" { decisionHandler(.allow); return }
        guard WebsiteAddress.isAllowed(address) else {
            if navigationAction.targetFrame?.isMainFrame == true { errorMessage = "This link is not an HTTPS webpage." }
            decisionHandler(.cancel)
            return
        }
        #if DEBUG
        if previewsEnabled, navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
            Task { @MainActor [weak self] in self?.load(address) }
            return
        }
        #endif
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType { decisionHandler(.allow) }
        else {
            errorMessage = "This file cannot be displayed in the website browser."
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open deliberately tapped new-window links here; ignore automatic pop-up windows.
        if navigationAction.navigationType == .linkActivated, let address = navigationAction.request.url,
           WebsiteAddress.isAllowed(address) { load(address) }
        return nil
    }

    #if DEBUG
    // Local, original HTML exercises WebKit and navigation without depending on a live manga website.
    private func loadPreview(_ address: URL, recording: Bool = true) {
        if recording {
            previewHistory = Array(previewHistory.prefix(previewIndex + 1))
            previewHistory.append(address)
            previewIndex = previewHistory.count - 1
        }
        url = address
        errorMessage = nil
        hasLoadedPage = false
        let chapter = address.path.contains("chapter-2") ? 2 : 1
        var next = URLComponents(url: address, resolvingAgainstBaseURL: false)!
        next.path = "/panel-reader-preview/chapter-2"
        next.query = nil
        next.fragment = nil
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Night Train · Chapter \(chapter) (preview)</title>
        <style>body{background:#11151d;color:#ecf3f0;font:17px -apple-system,sans-serif;margin:0;padding:28px}
        small{color:#8fdcc1}h1{font-size:34px;margin:22px 0 8px}.panel{height:260px;border-radius:20px;margin:28px 0;background:radial-gradient(circle at 72% 24%,#f3dfa0 0 22px,transparent 23px),linear-gradient(155deg,#354b62,#101621 64%);display:flex;align-items:flex-end;padding:24px}
        .train{border:2px solid #95dbc4;border-radius:12px;padding:20px;width:100%;letter-spacing:8px;color:#f3dfa0}
        p{color:#b5c4cc;line-height:1.6}a{display:block;background:#8fdcc1;color:#10241d;text-decoration:none;border-radius:14px;padding:17px;font-weight:600}</style></head>
        <body><small>OFFLINE TEST PAGE · ORIGINAL SAMPLE</small><h1>Night Train</h1><p>Chapter \(chapter)</p>
        <div class="panel"><div class="train">▢ ▢ ▢ ▢</div></div><p>The last train rolls beneath a quiet sky. One more chapter, then home.</p>
        <a href="\(next.url!.absoluteString)">Continue to chapter 2</a></body></html>
        """
        webView.loadHTMLString(html, baseURL: address)
    }
    #endif
}
