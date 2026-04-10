import SwiftUI

public struct CitationView: View {
    @Environment(\.markdownTheme) private var theme

    private let index: Int
    private let url: String?
    private let title: String?

    public init(index: Int, url: String?, title: String?) {
        self.index = index
        self.url = url
        self.title = title
    }

    public var body: some View {
        let label = title ?? "\(index)"
        let style = theme.citation

        Group {
            if let url, let destination = URL(string: url) {
                Link(destination: destination) {
                    pillContent(label: label, style: style)
                }
            } else {
                pillContent(label: label, style: style)
            }
        }
    }

    @ViewBuilder
    private func pillContent(label: String, style: CitationStyle) -> some View {
        Text(label)
            .font(.system(size: style.fontSize))
            .lineLimit(1)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .frame(maxWidth: 180)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
            )
    }
}
