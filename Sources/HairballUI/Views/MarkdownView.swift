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
///
/// Parsing and processor application are **deferred out of `init`** and
/// memoized through `MarkdownParseCache`. SwiftUI reconstructs value-type
/// Views on every parent body eval; parsing in `init` (as the earlier
/// implementation did) meant re-parsing the same markdown string many
/// times per second during scroll/streaming. Now `init` is O(1) — it just
/// stores the inputs — and the parse result is fetched once, then reused
/// until the string changes.
public struct MarkdownView: View, Equatable {
    @Environment(\.markdownTheme) private var theme

    private let payload: Payload

    // The three ways a MarkdownView can be driven. Split so that `init`
    // never touches the parser on the hot path (`.markdown`) and we still
    // honour callers that already own the `Document` (`.document`) or a
    // streaming pipeline (`.streaming`).
    private enum Payload {
        case markdown(String, ParseOptions, [any MarkdownProcessor])
        case document(Document)
        case streaming(AsyncStream<String>, ParseOptions, [any MarkdownProcessor])
    }

    // MARK: - Initializers

    /// Create from a raw markdown string. Parsing is deferred to body and
    /// cached — construction is cheap and safe to call per re-eval.
    public init(_ markdown: String, options: ParseOptions = .default, processors: [any MarkdownProcessor] = []) {
        self.payload = .markdown(markdown, options, processors)
    }

    /// Create from a pre-parsed `Document`.
    public init(document: Document) {
        self.payload = .document(document)
    }

    /// Create from a `MarkdownViewSource`.
    public init(source: MarkdownViewSource, options: ParseOptions = .default, processors: [any MarkdownProcessor] = []) {
        switch source {
        case .static(let markdown):
            self.payload = .markdown(markdown, options, processors)
        case .document(let document):
            self.payload = .document(document)
        case .streaming(let stream):
            self.payload = .streaming(stream, options, processors)
        }
    }

    /// Create from a result-builder DSL.
    public init(@MarkdownContentBuilder _ content: () -> [BlockNode]) {
        self.payload = .document(Document(blocks: content()))
    }

    // MARK: - Equatable

    // SwiftUI uses this conformance when the view is wrapped in
    // `EquatableView` / `.equatable()`. Most call sites should wrap their
    // `MarkdownView` in `.equatable()` so a parent re-eval with unchanged
    // inputs can short-circuit the whole subtree — no cache lookup, no
    // child rebuild.
    public static func == (lhs: MarkdownView, rhs: MarkdownView) -> Bool {
        switch (lhs.payload, rhs.payload) {
        case let (.markdown(lm, lo, lp), .markdown(rm, ro, rp)):
            // Streaming processor lists are small; type-name comparison
            // is the same fingerprint the cache uses, so this is a true
            // "same inputs" check.
            return lm == rm
                && lo.rawValue == ro.rawValue
                && processorTypeFingerprint(lp) == processorTypeFingerprint(rp)
        case let (.document(ld), .document(rd)):
            return ld == rd
        case (.streaming, .streaming):
            // Streams are reference-like; we can't meaningfully compare.
            // Falling through to `false` forces re-eval, which matches
            // the old behaviour.
            return false
        default:
            return false
        }
    }

    private static func processorTypeFingerprint(_ processors: [any MarkdownProcessor]) -> String {
        if processors.isEmpty { return "" }
        return processors.map { String(reflecting: type(of: $0)) }.joined(separator: "|")
    }

    // MARK: - Body

    public var body: some View {
        switch payload {
        case .markdown(let markdown, let options, let processors):
            // Hot path: look up or populate the cache. Parsing only
            // happens on the first body eval for a given string.
            let document = MarkdownParseCache.shared.document(
                for: markdown,
                options: options,
                processors: processors
            )
            MarkdownDocumentView(document: document)

        case .document(let document):
            MarkdownDocumentView(document: document)

        case .streaming(let stream, let options, let processors):
            StreamingMarkdownView(
                stream: stream,
                parser: MarkdownParser(options: options),
                processors: processors
            )
        }
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
