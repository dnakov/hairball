import Foundation

/// A collection of block nodes with a stable identity, suitable for use
/// in streaming/incremental rendering (e.g., SwiftUI `ForEach`).
public struct MarkdownBlockCollection: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public var blocks: [BlockNode]

    public init(id: String, blocks: [BlockNode]) {
        self.id = id
        self.blocks = blocks
    }
}

/// Strategy for how a document should be chunked into collections.
public enum ChunkingStrategy: Sendable {
    /// Each top-level block becomes its own chunk.
    case perBlock
    /// Group blocks into chunks of at most `n` blocks.
    case grouped(maxBlocks: Int)
    /// Group blocks into paragraph-level chunks: headings attach to the
    /// following content, and consecutive non-heading blocks are grouped.
    case paragraph
}

/// Chunks a document into `MarkdownBlockCollection` segments for
/// incremental/streaming rendering.
public struct MarkdownBlockChunker: Sendable {

    public let strategy: ChunkingStrategy

    public init(strategy: ChunkingStrategy = .paragraph) {
        self.strategy = strategy
    }

    /// Chunk a document according to the configured strategy.
    public func chunk(_ document: Document) -> [MarkdownBlockCollection] {
        switch strategy {
        case .perBlock:
            return chunkPerBlock(document.blocks)
        case .grouped(let maxBlocks):
            return chunkGrouped(document.blocks, maxBlocks: max(1, maxBlocks))
        case .paragraph:
            return chunkParagraphs(document.blocks)
        }
    }

    // MARK: - Per Block

    private func chunkPerBlock(_ blocks: [BlockNode]) -> [MarkdownBlockCollection] {
        var counts: [Int: Int] = [:]
        return blocks.map { block in
            let hash = block.hashValue
            let count = counts[hash, default: 0]
            counts[hash] = count + 1
            return MarkdownBlockCollection(id: "block-\(hash)-\(count)", blocks: [block])
        }
    }

    // MARK: - Grouped

    private func chunkGrouped(_ blocks: [BlockNode], maxBlocks: Int) -> [MarkdownBlockCollection] {
        var result: [MarkdownBlockCollection] = []
        var idCounts: [Int: Int] = [:]
        var i = 0

        while i < blocks.count {
            let end = min(i + maxBlocks, blocks.count)
            let slice = Array(blocks[i..<end])
            var hasher = Hasher()
            for block in slice { hasher.combine(block) }
            let hash = hasher.finalize()
            let count = idCounts[hash, default: 0]
            idCounts[hash] = count + 1
            result.append(MarkdownBlockCollection(id: "group-\(hash)-\(count)", blocks: slice))
            i = end
        }

        return result
    }

    // MARK: - Paragraph Chunking

    /// Groups blocks into logical paragraph-level chunks.
    /// Headings attach to the content that follows them.
    /// Adjacent non-heading, non-structural blocks are grouped together.
    private func chunkParagraphs(_ blocks: [BlockNode]) -> [MarkdownBlockCollection] {
        var result: [MarkdownBlockCollection] = []
        var currentChunk: [BlockNode] = []
        var idCounts: [Int: Int] = [:]

        func flushChunk() {
            guard !currentChunk.isEmpty else { return }
            var hasher = Hasher()
            for block in currentChunk { hasher.combine(block) }
            let hash = hasher.finalize()
            let count = idCounts[hash, default: 0]
            idCounts[hash] = count + 1
            result.append(MarkdownBlockCollection(id: "para-\(hash)-\(count)", blocks: currentChunk))
            currentChunk = []
        }

        for block in blocks {
            switch block {
            case .heading:
                // Flush any pending content before a heading
                flushChunk()
                // Start a new chunk with this heading
                currentChunk.append(block)

            case .thematicBreak:
                // Thematic breaks are natural chunk boundaries
                flushChunk()
                let tbHash = block.hashValue
                let tbCount = idCounts[tbHash, default: 0]
                idCounts[tbHash] = tbCount + 1
                result.append(MarkdownBlockCollection(id: "para-\(tbHash)-\(tbCount)", blocks: [block]))

            case .codeBlock, .table, .htmlBlock, .latexBlock, .blockDirective, .customBlock:
                // Structural blocks get their own chunk unless following a heading
                if currentChunk.count == 1, case .heading = currentChunk.first {
                    // Attach to the heading
                    currentChunk.append(block)
                    flushChunk()
                } else {
                    flushChunk()
                    currentChunk.append(block)
                    flushChunk()
                }

            case .orderedList, .unorderedList:
                // Lists attach to a preceding heading, otherwise standalone
                if currentChunk.count == 1, case .heading = currentChunk.first {
                    currentChunk.append(block)
                    flushChunk()
                } else {
                    flushChunk()
                    currentChunk.append(block)
                    flushChunk()
                }

            case .blockQuote:
                if currentChunk.count == 1, case .heading = currentChunk.first {
                    currentChunk.append(block)
                    flushChunk()
                } else {
                    flushChunk()
                    currentChunk.append(block)
                    flushChunk()
                }

            case .paragraph, .document:
                // Paragraphs accumulate, or attach to headings
                currentChunk.append(block)
            }
        }

        flushChunk()
        return result
    }
}
