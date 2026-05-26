import SwiftUI

struct FileGridItem: View {
    let file: HTMLFile

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "C4714B"))
                .frame(height: 56)

            Text(file.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(file.lastOpened.formatted(.relative(presentation: .named)))
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
