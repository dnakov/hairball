import SwiftUI

public struct HTMLBlockView: View {
    @Environment(\.markdownTheme) private var theme

    private let content: String

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("HTML")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.codeBlock.textColor.opacity(0.8))
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(theme.codeBlock.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
    }
}
