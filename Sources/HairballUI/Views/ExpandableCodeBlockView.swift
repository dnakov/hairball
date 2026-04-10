import SwiftUI
import Hairball

/// A code block that can be collapsed/expanded with animation.
/// Matches the `ExpandableCodeBlockView` found in the original binary.
public struct ExpandableCodeBlockView: View {
    @Environment(\.markdownTheme) private var theme
    @State private var isExpanded: Bool
    @State private var contentHeight: CGFloat = 0

    private let language: String?
    private let content: String
    private let collapsedHeight: CGFloat
    private let animationDuration: Double

    public init(
        language: String? = nil,
        content: String,
        collapsedHeight: CGFloat = 120,
        initiallyExpanded: Bool = false,
        animationDuration: Double = 0.3
    ) {
        self.language = language
        self.content = content
        self.collapsedHeight = collapsedHeight
        self._isExpanded = State(initialValue: initiallyExpanded)
        self.animationDuration = animationDuration
    }

    private var needsCollapsing: Bool {
        contentHeight > collapsedHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeBlockView(language: language, content: content)
                .frame(maxHeight: isExpanded || !needsCollapsing ? nil : collapsedHeight, alignment: .top)
                .clipped()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(ContentHeightKey.self) { height in
                    contentHeight = height
                }

            if needsCollapsing {
                expandCollapseOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlock.cornerRadius))
        .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    @ViewBuilder
    private var expandCollapseOverlay: some View {
        Button {
            withAnimation(.easeInOut(duration: animationDuration)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Spacer()
                Label(
                    isExpanded ? "Show less" : "Show more",
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        theme.codeBlock.backgroundColor.opacity(isExpanded ? 1 : 0),
                        theme.codeBlock.backgroundColor,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
