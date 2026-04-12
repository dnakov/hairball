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
    @Environment(\.tokenRevealConfig) private var revealConfig
    @Environment(\.revealGranularity) private var granularity

    private let blocks: [IdentifiedBlock]
    private let isStreaming: Bool
    private let blockAnimation: Animation?
    private let blockTransition: AnyTransition
    private let hasExplicitAnimation: Bool

    /// Single cursor driver shared across all blocks.
    @StateObject private var revealDriver = SmoothRevealDriver()

    public init(
        blocks: [IdentifiedBlock],
        isStreaming: Bool = false,
        blockAnimation: Animation? = nil,
        blockTransition: AnyTransition = .identity
    ) {
        self.blocks = blocks
        self.isStreaming = isStreaming
        self.blockAnimation = blockAnimation
        self.blockTransition = blockTransition
        self.hasExplicitAnimation = blockAnimation != nil
    }

    private var effectiveAnimation: Animation? {
        if hasExplicitAnimation { return blockAnimation }
        guard isStreaming && revealConfig.isEnabled else { return nil }
        return .easeOut(duration: revealConfig.duration)
    }

    private var effectiveTransition: AnyTransition {
        if hasExplicitAnimation { return blockTransition }
        guard isStreaming && revealConfig.isEnabled else { return .identity }
        return .opacity
    }

    private var usesCursorReveal: Bool {
        revealConfig.isEnabled && (isStreaming || !revealDriver.hasCaughtUp)
    }

    /// Total plain text character count across all blocks.
    private var totalDocumentLength: Int {
        blocks.map { blockPlainTextLength($0.block) }.reduce(0, +)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            if usesCursorReveal {
                cursorRevealBody
            } else {
                staticBody
            }
        }
        .foregroundColor(theme.foregroundColor)
        .onChange(of: totalDocumentLength) { newTotal in
            guard isStreaming && revealConfig.isEnabled else { return }
            revealDriver.timeConstant = revealConfig.duration
            revealDriver.linearMode = revealConfig.mode == .linear
            revealDriver.setTarget(Double(newTotal))
        }
        .onChange(of: revealConfig.duration) { newDuration in
            revealDriver.timeConstant = newDuration
        }
        .onChange(of: revealConfig.mode) { newMode in
            revealDriver.linearMode = newMode == .linear
        }
        .onAppear {
            if isStreaming && revealConfig.isEnabled {
                revealDriver.timeConstant = revealConfig.duration
                revealDriver.linearMode = revealConfig.mode == .linear
                // If content already exists (mid-stream recreation), snap near
                // the end so we don't replay. Only reveal from 0 when truly empty.
                let total = Double(totalDocumentLength)
                let snapPoint = total > 0 ? max(total - 1, 0) : 0
                revealDriver.snapTo(snapPoint)
                revealDriver.setTarget(total)
            }
        }
    }

    // MARK: - Cursor Reveal (continuous/linear)

    @ViewBuilder
    private var cursorRevealBody: some View {
        let offsets = computeBlockOffsets()
        let cursor = revealDriver.smoothPosition
        // For non-character granularity, keep blocks in the reveal path
        // so the effect can render the settle transition (e.g. Matrix decode flash)
        let canShortcut = granularity == .character

        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, item in
            let blockStart = offsets[index]
            let blockLength = blockPlainTextLength(item.block)
            let blockEnd = blockStart + blockLength
            let isLastBlock = index == blocks.count - 1
            let complete = !isLastBlock || !isStreaming

            if cursor >= Double(blockEnd) && complete && canShortcut {
                // Fully revealed, block finalized, character granularity — render normally
                BlockNodeView(node: item.block)
            } else if cursor > Double(blockStart) {
                // In reveal path — partially revealed, still growing, or non-character granularity
                let localPos = cursor - Double(blockStart)
                revealedBlockView(block: item.block, revealPosition: localPos, complete: complete)
            }
            // else: cursor hasn't reached this block yet — hidden
        }
    }

    private func revealedBlockView(block: BlockNode, revealPosition: Double, complete: Bool) -> AnyView {
        switch block {
        case .paragraph(let content):
            return AnyView(StreamingTextView(content: content, revealPosition: revealPosition, blockComplete: complete))
        case .heading(let level, let content):
            return AnyView(StreamingTextView(content: content, revealPosition: revealPosition, blockComplete: complete)
                .font(theme.headingStyle(for: level).font)
                .fontWeight(theme.headingStyle(for: level).weight))
        case .codeBlock(let lang, let code):
            return AnyView(StreamingCodeBlockView(language: lang, content: code, revealPosition: revealPosition, blockComplete: complete))
        case .blockQuote(let children):
            return AnyView(BlockquoteContainer {
                cursorRevealBlocks(children, cursor: revealPosition, parentComplete: complete)
            })
        case .unorderedList(let tight, let items):
            return AnyView(cursorRevealList(items: items, cursor: revealPosition, tight: tight, parentComplete: complete))
        case .orderedList(let startIndex, _, let items):
            return AnyView(cursorRevealList(items: items, cursor: revealPosition, tight: false, parentComplete: complete, startIndex: startIndex))
        default:
            return AnyView(BlockNodeView(node: block))
        }
    }

    // MARK: - Recursive Cursor Dispatch

    @ViewBuilder
    private func cursorRevealBlocks(_ children: [BlockNode], cursor: Double, parentComplete: Bool) -> some View {
        let offsets = computeOffsets(for: children)
        let canShortcut = granularity == .character
        ForEach(Array(children.enumerated()), id: \.offset) { index, child in
            let start = offsets[index]
            let length = blockPlainTextLength(child)
            let end = start + length
            let isLastChild = index == children.count - 1
            let complete = !isLastChild || parentComplete

            if cursor >= Double(end) && complete && canShortcut {
                BlockNodeView(node: child)
            } else if cursor > Double(start) {
                revealedBlockView(block: child, revealPosition: cursor - Double(start), complete: complete)
            }
        }
    }

    private func cursorRevealList(
        items: [ListItem],
        cursor: Double,
        tight: Bool,
        parentComplete: Bool,
        startIndex: Int? = nil
    ) -> some View {
        let lengths = items.map { $0.children.map(blockPlainTextLength).reduce(0, +) }
        let offsets = Self.cumulativeOffsets(lengths)
        let spacing = tight ? theme.list.tightItemSpacing : theme.list.itemSpacing

        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isLastItem = index == items.count - 1
                let complete = !isLastItem || parentComplete
                cursorRevealListItem(
                    item: item,
                    index: index,
                    cursor: cursor,
                    start: offsets[index],
                    end: offsets[index] + lengths[index],
                    spacing: spacing,
                    startIndex: startIndex,
                    complete: complete
                )
            }
        }
    }

    @ViewBuilder
    private func cursorRevealListItem(
        item: ListItem,
        index: Int,
        cursor: Double,
        start: Int,
        end: Int,
        spacing: CGFloat,
        startIndex: Int?,
        complete: Bool
    ) -> some View {
        if cursor > Double(start) {
            let marker = listMarker(for: item, index: index, startIndex: startIndex)
            ListItemContainer(marker: marker) {
                listItemChildren(item: item, cursor: cursor, start: start, end: end, spacing: spacing, parentComplete: complete)
            }
        }
    }

    @ViewBuilder
    private func listItemChildren(
        item: ListItem,
        cursor: Double,
        start: Int,
        end: Int,
        spacing: CGFloat,
        parentComplete: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if cursor >= Double(end) && parentComplete && granularity == .character {
                ForEach(Array(item.children.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                }
            } else {
                cursorRevealBlocks(item.children, cursor: cursor - Double(start), parentComplete: parentComplete)
            }
        }
    }

    private func listMarker(for item: ListItem, index: Int, startIndex: Int?) -> ListMarker {
        if let startIndex { return .ordered(startIndex + index) }
        if let checkbox = item.checkbox { return .checkbox(checkbox) }
        return .unordered
    }

    // MARK: - Offset Computation

    private func computeBlockOffsets() -> [Int] {
        computeOffsets(for: blocks.map(\.block))
    }

    private func computeOffsets(for children: [BlockNode]) -> [Int] {
        Self.cumulativeOffsets(children.map(blockPlainTextLength))
    }

    private static func cumulativeOffsets(_ lengths: [Int]) -> [Int] {
        var offsets: [Int] = []
        var running = 0
        for length in lengths {
            offsets.append(running)
            running += length
        }
        return offsets
    }

    // MARK: - Static / Batched Body

    @ViewBuilder
    private var staticBody: some View {
        ForEach(blocks) { item in
            BlockNodeView(node: item.block)
                .transition(effectiveTransition)
                .animation(effectiveAnimation, value: item.id)
        }
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

    /// Minimum interval between re-parses.
    /// This acts as a content buffer — tokens accumulate in memory but the
    /// document only updates when the interval fires. Set this to match your
    /// `TokenRevealConfig.duration` so animation batches align with parse batches.
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
    /// Previous block list — used to detect structural instability in the last block
    private var previousBlocks: [BlockNode] = []

    // MARK: - Init

    public init(
        processors: [any MarkdownProcessor] = [],
        parseOptions: ParseOptions = .default,
        throttleInterval: TimeInterval = 0.016,
        blockAnimation: Animation? = nil,
        blockTransition: AnyTransition = .identity
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

        let newBlocks: [BlockNode]
        if isFinished {
            // Final parse — render everything with full formatting
            newBlocks = doc.blocks
        } else {
            // Streaming — the last block is always shown as a plain paragraph
            // to prevent flashing between block types (paragraph → code → table)
            // as syntax completes. All blocks before the last are fully committed
            // (a new block started after them, proving their type is final).
            newBlocks = stabilizeLastBlock(doc.blocks)
        }

        self.document = Document(blocks: newBlocks, metadata: doc.metadata)
        self.identifiedBlocks = IdentifiedBlock.identify(newBlocks)
        self.previousBlocks = doc.blocks
    }

    /// Prevents the last block from flashing during streaming.
    ///
    /// Most block types are recognized immediately by their prefix (`#`, `>`, `-`, `` ``` ``).
    /// The main problem is tables: `| A | B |` parses as a paragraph until the separator
    /// row `|---|---|` arrives, then it becomes a table and the paragraph disappears.
    ///
    /// Fix: if the last block is a paragraph starting with `|`, suppress it — it's likely
    /// a table header that hasn't been recognized yet. It'll appear as a full table
    /// once the separator arrives.
    private func stabilizeLastBlock(_ blocks: [BlockNode]) -> [BlockNode] {
        guard let last = blocks.last else { return blocks }

        if case .paragraph(let content) = last {
            let text = content.compactMap { node -> String? in
                if case .text(let s) = node { return s }
                return nil
            }.joined().trimmingCharacters(in: .whitespaces)

            // If it starts with | and has multiple |, it's a table row waiting for its separator
            if text.hasPrefix("|") && text.filter({ $0 == "|" }).count >= 3 {
                return Array(blocks.dropLast())
            }
        }

        return blocks
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
