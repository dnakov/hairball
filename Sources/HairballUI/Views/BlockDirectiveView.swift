import SwiftUI
import Hairball

public struct BlockDirectiveView: View {
    @Environment(\.markdownTheme) private var theme
    @State private var isExpanded = true

    private let name: String
    private let arguments: String?
    private let children: [BlockNode]

    public init(name: String, arguments: String?, children: [BlockNode]) {
        self.name = name
        self.arguments = arguments
        self.children = children
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text("@\(name)")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)

                    if let arguments, !arguments.isEmpty {
                        Text("(\(arguments))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, block in
                        BlockNodeView(node: block)
                    }
                }
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            }
        }
        .background(theme.codeBlock.backgroundColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
