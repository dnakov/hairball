import SwiftUI
import Hairball

// MARK: - MarkdownViewSource

public enum MarkdownViewSource {
    case `static`(String)
    case document(Document)
    case streaming(AsyncStream<String>)
}

// MARK: - MarkdownView

/// The main public entry point for rendering markdown content.
public struct MarkdownView: View {
    @Environment(\.markdownTheme) private var theme

    private let source: MarkdownViewSource
    private let parser: MarkdownParser
    private let processors: [any MarkdownProcessor]

    // MARK: - Initializers

    /// Create from a raw markdown string.
    public init(_ markdown: String, options: ParseOptions = .default, processors: [any MarkdownProcessor] = []) {
        let parser = MarkdownParser(options: options)
        var doc = parser.parse(markdown)
        for processor in processors {
            doc = processor.process(doc)
        }
        self.source = .document(doc)
        self.parser = parser
        self.processors = processors
    }

    /// Create from a pre-parsed `Document`.
    public init(document: Document) {
        self.source = .document(document)
        self.parser = MarkdownParser()
        self.processors = []
    }

    /// Create from a `MarkdownViewSource`.
    public init(source: MarkdownViewSource, options: ParseOptions = .default, processors: [any MarkdownProcessor] = []) {
        let parser = MarkdownParser(options: options)
        switch source {
        case .static(let markdown):
            var doc = parser.parse(markdown)
            for processor in processors {
                doc = processor.process(doc)
            }
            self.source = .document(doc)
        default:
            self.source = source
        }
        self.parser = parser
        self.processors = processors
    }

    /// Create from a result-builder DSL.
    public init(@MarkdownContentBuilder _ content: () -> [BlockNode]) {
        self.source = .document(Document(blocks: content()))
        self.parser = MarkdownParser()
        self.processors = []
    }

    // MARK: - Body

    public var body: some View {
        switch source {
        case .static:
            // All .static sources are pre-parsed to .document in init,
            // so this case is unreachable. Kept for exhaustiveness.
            EmptyView()

        case .document(let document):
            documentContent(for: document)

        case .streaming(let stream):
            StreamingMarkdownView(stream: stream, parser: parser, processors: processors)
        }
    }

    // MARK: - Private

    @ViewBuilder
    private func documentContent(for document: Document) -> some View {
        MarkdownDocumentView(document: document)
    }

    private func process(_ document: Document) -> Document {
        var doc = document
        for processor in processors {
            doc = processor.process(doc)
        }
        return doc
    }
}

// MARK: - Streaming Support

private struct StreamingMarkdownView: View {
    @Environment(\.markdownTheme) private var theme

    let stream: AsyncStream<String>
    let parser: MarkdownParser
    let processors: [any MarkdownProcessor]

    @State private var accumulated = ""
    @State private var document = Document(blocks: [])

    var body: some View {
        let identified = IdentifiedBlock.identify(document.blocks)
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(identified) { item in
                BlockNodeView(node: item.block)
            }
        }
        .task {
            for await chunk in stream {
                accumulated += chunk
                var doc = parser.parse(accumulated)
                for processor in processors {
                    doc = processor.process(doc)
                }
                document = doc
            }
        }
    }
}
