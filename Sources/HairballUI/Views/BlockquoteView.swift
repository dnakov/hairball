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
            Rectangle()
                .fill(style.borderColor)
                .frame(width: style.borderWidth)

            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                }
            }
            .padding(.leading, style.padding.leading)
            .padding(.trailing, style.padding.trailing)
            .padding(.vertical, style.padding.top)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(style.backgroundColor)
        .foregroundColor(style.textColor)
    }
}
