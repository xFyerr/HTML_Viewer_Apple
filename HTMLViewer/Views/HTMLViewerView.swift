import SwiftUI

struct HTMLViewerView: View {
    let file: HTMLFile
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let url = file.resolveURL() {
                WebViewWrapper(url: url, onScroll: showControlsTemporarily)
                    .ignoresSafeArea()
            } else {
                unavailableView
            }

            if showControls {
                floatingBackButton
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
        }
        // Tap anywhere (outside the back button) to toggle controls
        .contentShape(Rectangle())
        .onTapGesture {
            toggleControls()
        }
        .onAppear {
            scheduleAutoHide()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Controls overlay

    private var floatingBackButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                .frame(width: 34, height: 34)
        }
        .padding(.leading, 16)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var unavailableView: some View {
        ZStack {
            Color(hex: "1A1A1A").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "C4714B"))
                Text("File unavailable")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("The file may have been moved or deleted.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "888888"))
                Button("Go back") { dismiss() }
                    .foregroundColor(Color(hex: "C4714B"))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Control visibility helpers

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    func showControlsTemporarily() {
        withAnimation { showControls = true }
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showControls = false }
            }
        }
    }
}
