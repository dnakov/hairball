import SwiftUI
import Hairball

public struct ParagraphView: View {
    private let content: [InlineNode]

    public init(content: [InlineNode]) {
        self.content = content
    }

    public static func == (lhs: ParagraphView, rhs: ParagraphView) -> Bool {
        lhs.content == rhs.content
    }

    public var body: some View {
        ParagraphBody(content: content)
    }
}

/// Inner body that reads the environment — separated so the Equatable check on
/// ParagraphView can skip re-renders when content hasn't changed.
private struct ParagraphBody: View {
    @Environment(\.markdownTheme) private var theme
    let content: [InlineNode]

    var body: some View {
        InlineTextRenderer(theme: theme).render(
            content,
            baseStyle: InlineStyle(
                font: theme.bodyFont,
                foregroundColor: theme.bodyTextColor
            )
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }
}
