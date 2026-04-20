import SwiftUI
import Hairball

/// A preview-oriented markdown view that supports truncation, animation, and loading states.
/// Matches the `MarkdownPreviewView` from the original binary.
public struct MarkdownPreviewView: View {
    @Environment(\.markdownTheme) private var theme

    private let markdown: String
    private let maxBlocks: Int?
    private let showGradientFade: Bool
    private let options: ParseOptions
    private let processors: [any MarkdownProcessor]

    public init(
        _ markdown: String,
        maxBlocks: Int? = nil,
        showGradientFade: Bool = true,
        options: ParseOptions = .default,
        processors: [any MarkdownProcessor] = []
    ) {
        self.markdown = markdown
        self.maxBlocks = maxBlocks
        self.showGradientFade = showGradientFade
        self.options = options
        self.processors = processors
    }

    public var body: some View {
        // Route through the shared parse cache so re-evals for the same
        // markdown don't re-run the parser + processor chain.
        let document = MarkdownParseCache.shared.document(
            for: markdown,
            options: options,
            processors: processors
        )
        let blocks = truncatedBlocks(from: document)
        let isTruncated = maxBlocks != nil && document.blocks.count > (maxBlocks ?? 0)

        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                }
            }

            if isTruncated && showGradientFade {
                LinearGradient(
                    colors: [.clear, Color(red: 1, green: 1, blue: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .allowsHitTesting(false)
            }
        }
    }

    private func truncatedBlocks(from document: Document) -> [BlockNode] {
        guard let maxBlocks else { return document.blocks }
        return Array(document.blocks.prefix(maxBlocks))
    }
}
