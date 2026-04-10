import SwiftUI

public struct ThematicBreakView: View {
    @Environment(\.markdownTheme) private var theme

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(theme.thematicBreak.color)
            .frame(height: theme.thematicBreak.height)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.thematicBreak.verticalPadding)
    }
}
