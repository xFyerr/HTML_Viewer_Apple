import SwiftUI

struct EmptyStateView: View {
    let onOpenTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "2A2A2A"))
                    .frame(width: 72, height: 72)

                Image(systemName: "doc.richtext")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "C4714B").opacity(0.7))
            }

            Spacer().frame(height: 20)

            Text("No Recent Files")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer().frame(height: 8)

            Text("Open a .html file from any app,\nor browse from Files.")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "888888"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer().frame(height: 28)

            Button(action: onOpenTapped) {
                HStack(spacing: 9) {
                    Image(systemName: "folder")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open from Files")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 15)
                .background(Color(hex: "C4714B"))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
