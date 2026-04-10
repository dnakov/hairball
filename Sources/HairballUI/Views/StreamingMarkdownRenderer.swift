import SwiftUI
import Combine
import Hairball

// MARK: - MarkdownDocumentView

/// The lowest-level markdown rendering view. Takes a `Document` and renders it.
/// No streaming logic, no parsing, no throttling — just rendering.
///
/// Use this when you own the parsing pipeline and just need the view:
/// ```swift
/// @State var document = Document(blocks: [])
///
/// MarkdownDocumentView(document: document)
///
/// // Update document yourself whenever you want
/// document = MarkdownParser().parse(myText)
/// ```
public struct MarkdownDocumentView: View {
    @Environment(\.markdownTheme) private var theme

    private let document: Document
    private let isStreaming: Bool
    private let blockAnimation: Animation?
    private let blockTransition: AnyTransition

    public init(
        document: Document,
        isStreaming: Bool = false,
        blockAnimation: Animation? = nil,
        blockTransition: AnyTransition = .identity
    ) {
        self.document = document
        self.isStreaming = isStreaming
        self.blockAnimation = blockAnimation
        self.blockTransition = blockTransition
    }

    public var body: some View {
        let identified = IdentifiedBlock.identify(document.blocks)
        MarkdownBlocksView(
            blocks: identified,
            isStreaming: isStreaming,
            blockAnimation: blockAnimation,
            blockTransition: blockTransition
        )
    }
}

// MARK: - MarkdownBlocksView

/// Renders an array of `IdentifiedBlock` with streaming-aware animation.
///
/// Key design for smooth streaming:
/// - New blocks appear with `blockTransition` (e.g. opacity fade)
/// - The last block during streaming has NO animation so text grows instantly
/// - Layout changes from text growing don't animate (no jumpy paragraph shifting)
///
/// Use this when you've already parsed and identified your blocks:
/// ```swift
/// let blocks = IdentifiedBlock.identify(document.blocks)
/// MarkdownBlocksView(blocks: blocks, isStreaming: true)
/// ```
public struct MarkdownBlocksView: View {
    @Environment(\.markdownTheme) private var theme

    private let blocks: [IdentifiedBlock]
    private let isStreaming: Bool
    private let blockAnimation: Animation?
    private let blockTransition: AnyTransition

    public init(
        blocks: [IdentifiedBlock],
        isStreaming: Bool = false,
        blockAnimation: Animation? = .easeOut(duration: 0.15),
        blockTransition: AnyTransition = .opacity
    ) {
        self.blocks = blocks
        self.isStreaming = isStreaming
        self.blockAnimation = blockAnimation
        self.blockTransition = blockTransition
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(blocks) { item in
                let isLast = item.id == blocks.last?.id

                // For the last block during streaming, use StreamingTextView
                // to fade in new tokens. For all other blocks, render normally.
                if isLast && isStreaming, case .paragraph(let content) = item.block {
                    StreamingTextView(content: content, isStreaming: true)
                } else if isLast && isStreaming, case .heading(let level, let content) = item.block {
                    // Headings can also be the actively streaming block
                    StreamingTextView(content: content, isStreaming: true)
                        .font(theme.headingStyle(for: level).font)
                        .fontWeight(theme.headingStyle(for: level).weight)
                } else {
                    BlockNodeView(node: item.block)
                        .transition(blockTransition)
                }
            }
        }
        .foregroundColor(theme.foregroundColor)
        .animation(blockAnimation, value: blocks.map(\.id))
    }
}

// MARK: - Text Appearance Style

/// Controls how text appears within a paragraph as it streams in.
public enum TextAppearanceStyle: Sendable {
    /// Text simply appears instantly as tokens arrive (default, most performant).
    case instant
    /// New text fades in with the given duration.
    case fade(duration: Double)
}

// MARK: - StreamingMarkdownRenderer

/// Convenience object that owns the streaming pipeline: text accumulation,
/// throttled parsing, processing, and block identity.
///
/// Use this when you want Hairball to manage the streaming for you:
/// ```swift
/// let renderer = StreamingMarkdownRenderer()
/// for await token in llmStream {
///     renderer.append(token)
/// }
/// renderer.finish()
/// ```
///
/// If you already have your own streaming mechanism, skip this class and use
/// `MarkdownDocumentView` or `MarkdownBlocksView` directly:
/// ```swift
/// @State var doc = Document(blocks: [])
/// let parser = MarkdownParser()
///
/// // Your own streaming loop:
/// accumulated += token
/// doc = parser.parse(accumulated)
///
/// // Your view:
/// MarkdownDocumentView(document: doc, isStreaming: true,
///     blockAnimation: .easeOut(duration: 0.2),
///     blockTransition: .opacity)
/// ```
@MainActor
public final class StreamingMarkdownRenderer: ObservableObject {

    // MARK: - Published state

    /// The current parsed document.
    @Published public private(set) var document: Document = Document(blocks: [])

    /// Blocks with stable identities for use in ForEach.
    @Published public private(set) var identifiedBlocks: [IdentifiedBlock] = []

    /// The raw accumulated markdown text.
    @Published public private(set) var rawText: String = ""

    /// Whether the stream has finished.
    @Published public private(set) var isFinished: Bool = false

    /// Whether any content has been received.
    @Published public private(set) var isEmpty: Bool = true

    /// Convenience: the current blocks.
    public var blocks: [BlockNode] { document.blocks }

    /// Number of blocks parsed so far.
    public var blockCount: Int { document.blocks.count }

    // MARK: - Configuration

    /// Processors to apply after parsing.
    public var processors: [any MarkdownProcessor]

    /// Parser options.
    public var parseOptions: ParseOptions

    /// Minimum interval between re-parses (throttling for performance).
    public var throttleInterval: TimeInterval

    /// Animation for new blocks appearing.
    public var blockAnimation: Animation?

    /// Transition for new blocks appearing.
    public var blockTransition: AnyTransition

    // MARK: - Private

    private var fullParser: MarkdownParser
    private var throttleTask: Task<Void, Never>?
    private var pendingUpdate = false
    private var lastUpdateTime: Date = .distantPast

    // MARK: - Init

    public init(
        processors: [any MarkdownProcessor] = [],
        parseOptions: ParseOptions = .default,
        throttleInterval: TimeInterval = 0.016,
        blockAnimation: Animation? = .easeOut(duration: 0.2),
        blockTransition: AnyTransition = .opacity
    ) {
        self.processors = processors
        self.parseOptions = parseOptions
        self.throttleInterval = throttleInterval
        self.blockAnimation = blockAnimation
        self.blockTransition = blockTransition
        self.fullParser = MarkdownParser(options: parseOptions)
    }

    // MARK: - Streaming Control

    /// Append a token/chunk of markdown text.
    public func append(_ text: String) {
        rawText += text
        isEmpty = false
        scheduleUpdate()
    }

    /// Signal that the stream is complete. Does a final parse.
    public func finish() {
        isFinished = true
        throttleTask?.cancel()
        performUpdate()
    }

    /// Reset to empty state for reuse.
    public func reset() {
        throttleTask?.cancel()
        rawText = ""
        document = Document(blocks: [])
        identifiedBlocks = []
        isFinished = false
        isEmpty = true
        lastUpdateTime = .distantPast
    }

    /// Replace all content.
    public func setContent(_ markdown: String) {
        reset()
        rawText = markdown
        isEmpty = markdown.isEmpty
        performUpdate()
    }

    // MARK: - Throttled Updates

    private func scheduleUpdate() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)

        if timeSinceLastUpdate >= throttleInterval {
            performUpdate()
        } else if !pendingUpdate {
            pendingUpdate = true
            let delay = throttleInterval - timeSinceLastUpdate
            throttleTask?.cancel()
            throttleTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.performUpdate()
                self?.pendingUpdate = false
            }
        }
    }

    private func performUpdate() {
        lastUpdateTime = Date()
        var doc = fullParser.parse(rawText)
        for processor in processors {
            doc = processor.process(doc)
        }
        self.document = doc
        self.identifiedBlocks = IdentifiedBlock.identify(doc.blocks)
    }
}

// MARK: - StreamingMarkdownContentView

/// Convenience view that connects a `StreamingMarkdownRenderer` to `MarkdownBlocksView`.
/// If you own your own streaming pipeline, use `MarkdownDocumentView` or `MarkdownBlocksView` directly.
public struct StreamingMarkdownContentView: View {
    @ObservedObject var renderer: StreamingMarkdownRenderer

    public init(renderer: StreamingMarkdownRenderer) {
        self.renderer = renderer
    }

    public var body: some View {
        MarkdownBlocksView(
            blocks: renderer.identifiedBlocks,
            isStreaming: !renderer.isFinished,
            blockAnimation: renderer.blockAnimation,
            blockTransition: renderer.blockTransition
        )
    }
}

// MARK: - ChatMarkdownMessageView

/// Convenience view for chat bubble rendering.
public struct ChatMarkdownMessageView: View {
    @ObservedObject var renderer: StreamingMarkdownRenderer

    private let role: ChatMessageConfiguration.Role

    public init(role: ChatMessageConfiguration.Role, renderer: StreamingMarkdownRenderer) {
        self.role = role
        self.renderer = renderer
    }

    public var body: some View {
        let config = ChatMessageConfiguration(role: role)
        StreamingMarkdownContentView(renderer: renderer)
            .chatMessageConfiguration(config)
    }
}

// MARK: - AsyncStream convenience

extension StreamingMarkdownRenderer {
    /// Connect an AsyncStream of string tokens directly.
    public func connect(to stream: AsyncStream<String>) async {
        for await token in stream {
            append(token)
        }
        finish()
    }

    /// Connect an AsyncThrowingStream of string tokens.
    public func connect<E: Error>(to stream: AsyncThrowingStream<String, E>) async throws {
        for try await token in stream {
            append(token)
        }
        finish()
    }
}
