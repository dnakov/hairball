import SwiftUI
import Hairball

public struct HeadingView: View {
    private let level: Int
    private let content: [InlineNode]

    public init(level: Int, content: [InlineNode]) {
        self.level = level
        self.content = content
    }

    public static func == (lhs: HeadingView, rhs: HeadingView) -> Bool {
        lhs.level == rhs.level && lhs.content == rhs.content
    }

    public var body: some View {
        HeadingBody(level: level, content: content)
    }
}

private struct HeadingBody: View {
    @Environment(\.markdownTheme) private var theme
    let level: Int
    let content: [InlineNode]

    var body: some View {
        let style = theme.headingStyle(for: level)
        InlineTextRenderer(theme: theme).render(
            content,
            baseStyle: InlineStyle(
                font: style.font,
                fontWeight: style.weight,
                foregroundColor: style.color
            )
        )
            .padding(.top, style.topSpacing * theme.headingTopSpacingMultiplier)
            .padding(.bottom, style.bottomSpacing * theme.headingBottomSpacingMultiplier)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityAddTraits(.isHeader)
    }
}
