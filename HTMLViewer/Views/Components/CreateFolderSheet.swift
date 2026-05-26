import SwiftUI

struct CreateFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String) -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1A1A1A").ignoresSafeArea()
                VStack(spacing: 20) {
                    TextField("Folder name", text: $name)
                        .focused($focused)
                        .padding()
                        .background(Color(hex: "2A2A2A"))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .tint(Color(hex: "C4714B"))
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "C4714B"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                        dismiss()
                    }
                    .foregroundColor(
                        name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(hex: "666666")
                            : Color(hex: "C4714B")
                    )
                }
            }
        }
        .onAppear { focused = true }
    }
}
