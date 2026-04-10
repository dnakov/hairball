import SwiftUI
import Hairball

public struct BlockquoteView: View {
    @Environment(\.markdownTheme) private var theme

    private let children: [BlockNode]

    public init(children: [BlockNode]) {
        self.children = children
    }

    public var body: some View {
        let style = theme.blockquote

        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: style.borderWidth / 2)
                .fill(style.borderColor)
                .frame(width: style.borderWidth)

            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                }
            }
            .padding(style.padding)
        }
        .background(style.backgroundColor)
        .foregroundColor(style.textColor)
    }
}
