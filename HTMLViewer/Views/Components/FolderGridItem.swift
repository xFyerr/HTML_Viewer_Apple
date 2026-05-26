import SwiftUI

struct FolderGridItem: View {
    let folder: Folder
    let fileCount: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "5B9BD5"))
                .frame(height: 56)

            Text(folder.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "666666"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color(hex: "2A2A2A"))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}
