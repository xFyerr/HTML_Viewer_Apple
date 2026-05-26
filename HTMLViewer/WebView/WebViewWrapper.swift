import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        // Prevent WKWebView from adjusting insets for the safe area — we want
        // the HTML content to fill all the way to the physical edges.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        webView.isOpaque = true
        webView.backgroundColor = UIColor(hex: "1A1A1A")
        webView.scrollView.backgroundColor = UIColor(hex: "1A1A1A")

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if this is the first call (webView.url == nil) so we
        // don't redundantly reload on every SwiftUI state update.
        guard webView.url == nil else { return }
        context.coordinator.load(url: url, into: webView)
    }

    static func dismantleUIView(_: WKWebView, coordinator: Coordinator) {
        coordinator.releaseAccess()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var accessedURL: URL?

        /// Starts security-scoped access, then loads the file URL.
        func load(url: URL, into webView: WKWebView) {
            releaseAccess()

            let accessed = url.startAccessingSecurityScopedResource()
            if accessed { accessedURL = url }

            // Allow read access to the parent directory so the HTML file can
            // load relative resources (images, CSS, JS) stored alongside it.
            let directory = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: directory)
        }

        func releaseAccess() {
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
        }

        deinit {
            releaseAccess()
        }
    }
}
