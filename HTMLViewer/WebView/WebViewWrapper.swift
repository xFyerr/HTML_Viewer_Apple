import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    var onScroll: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        webView.isOpaque = true
        webView.backgroundColor = UIColor(hex: "1A1A1A")
        webView.scrollView.backgroundColor = UIColor(hex: "1A1A1A")

        context.coordinator.startObservingScroll(on: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onScroll = onScroll
        guard webView.url == nil else { return }
        context.coordinator.load(url: url, into: webView)
    }

    static func dismantleUIView(_: WKWebView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onScroll: (() -> Void)?

        private var accessedURL: URL?
        private var tempDir: URL?
        private var scrollObservation: NSKeyValueObservation?

        func startObservingScroll(on webView: WKWebView) {
            scrollObservation = webView.scrollView.observe(\.contentOffset, options: [.new, .old]) { [weak self] _, change in
                guard let newY = change.newValue?.y, let oldY = change.oldValue?.y,
                      newY != oldY else { return }
                DispatchQueue.main.async { self?.onScroll?() }
            }
        }

        func load(url: URL, into webView: WKWebView) {
            cleanup(keepObservation: true)

            let accessed = url.startAccessingSecurityScopedResource()
            if accessed { accessedURL = url }

            let fm = FileManager.default
            let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

            do {
                try fm.copyItem(at: url.deletingLastPathComponent(), to: staging)
                tempDir = staging
                let stagedFile = staging.appendingPathComponent(url.lastPathComponent)
                webView.loadFileURL(stagedFile, allowingReadAccessTo: staging)
            } catch {
                print("Staging copy failed: \(error)")
                if let html = try? String(contentsOf: url, encoding: .utf8) {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }

        func cleanup(keepObservation: Bool = false) {
            accessedURL?.stopAccessingSecurityScopedResource()
            accessedURL = nil
            if let dir = tempDir {
                try? FileManager.default.removeItem(at: dir)
                tempDir = nil
            }
            if !keepObservation {
                scrollObservation = nil
            }
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            print("WKWebView provisional load failed: \(error)")
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            print("WKWebView navigation failed: \(error)")
        }

        deinit { cleanup() }
    }
}
