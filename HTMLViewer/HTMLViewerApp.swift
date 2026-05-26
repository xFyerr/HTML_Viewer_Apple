import SwiftUI

@main
struct HTMLViewerApp: App {
    @StateObject private var filesManager = RecentFilesManager()
    @State private var urlToOpen: URL?

    var body: some Scene {
        WindowGroup {
            HomeView(pendingURL: $urlToOpen)
                .environmentObject(filesManager)
                .onOpenURL { url in
                    // Handle files opened from other apps (Files, Safari, Share Sheet)
                    urlToOpen = url
                }
        }
    }
}
