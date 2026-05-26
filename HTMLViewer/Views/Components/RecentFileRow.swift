import SwiftUI

struct RecentFileRow: View {
    let file: HTMLFile

    var body: some View {
        HStack(spacing: 14) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "2A2A2A"))
                    .frame(width: 46, height: 46)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "C4714B"))
            }

            // Name + timestamp
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(file.lastOpened.formatted(.relative(presentation: .named)))
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
