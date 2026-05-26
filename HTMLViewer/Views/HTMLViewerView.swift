import SwiftUI

struct HTMLViewerView: View {
    let file: HTMLFile
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let url = file.resolveURL() {
                WebViewWrapper(url: url)
                    .ignoresSafeArea()
            } else {
                unavailableView
            }

            if showControls {
                floatingBackButton
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
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
        .statusBarHidden(!showControls)
    }

    // MARK: - Controls overlay

    private var floatingBackButton: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.leading, 20)
                .padding(.top, 56) // below status bar

                Spacer()
            }
            Spacer()
        }
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
        withAnimation {
            showControls.toggle()
        }
        if showControls { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showControls = false }
            }
        }
    }
}
