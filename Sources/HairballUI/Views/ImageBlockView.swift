import SwiftUI
import Hairball

public struct ImageBlockView: View {
    @Environment(\.markdownTheme) private var theme
    @Environment(\.imageProvider) private var imageProvider

    private let source: String
    private let title: String?
    private let alt: [InlineNode]

    public init(source: String, title: String?, alt: [InlineNode]) {
        self.source = source
        self.title = title
        self.alt = alt
    }

    public var body: some View {
        if let url = URL(string: source) {
            VStack(alignment: .center, spacing: 4) {
                imageProvider.makeImage(url: url, title: title, alt: alt)
                    .frame(maxWidth: .infinity)

                if let title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                Text("Invalid image URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        }
    }
}
