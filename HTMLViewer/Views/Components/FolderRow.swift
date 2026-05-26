import SwiftUI

struct FolderRow: View {
    let folder: Folder
    let fileCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "2A4A6A"))
                    .frame(width: 46, height: 46)
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "5B9BD5"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "666666"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "3A3A3A"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
