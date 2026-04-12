import SwiftUI
import Hairball

// MARK: - Blockquote Container

/// The visual chrome for a blockquote — border bar, background, padding.
/// Used by both `BlockquoteView` (normal) and cursor reveal (streaming).
struct BlockquoteContainer<Content: View>: View {
    @Environment(\.markdownTheme) private var theme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let style = theme.blockquote
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(style.borderColor)
                .frame(width: style.borderWidth)

            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                content
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

// MARK: - BlockquoteView

public struct BlockquoteView: View {
    private let children: [BlockNode]

    public init(children: [BlockNode]) {
        self.children = children
    }

    public var body: some View {
        BlockquoteContainer {
            ForEach(Array(children.enumerated()), id: \.offset) { _, block in
                BlockNodeView(node: block)
            }
        }
    }
}
