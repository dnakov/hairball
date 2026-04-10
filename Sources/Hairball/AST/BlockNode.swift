import Foundation

// MARK: - Supporting Types

public enum CheckboxState: Equatable, Hashable, Sendable {
    case checked
    case unchecked
}

public struct ListItem: Equatable, Hashable, Sendable {
    public var children: [BlockNode]
    public var checkbox: CheckboxState?

    public init(children: [BlockNode], checkbox: CheckboxState? = nil) {
        self.children = children
        self.checkbox = checkbox
    }
}

public enum MarkdownTableColumnAlignment: Equatable, Hashable, Sendable {
    case left
    case center
    case right
    case none
}

public struct MarkdownTableRow: Equatable, Hashable, Sendable {
    public var cells: [MarkdownTableCell]

    public init(cells: [MarkdownTableCell]) {
        self.cells = cells
    }
}

public struct MarkdownTableCell: Equatable, Hashable, Sendable {
    public var content: [InlineNode]

    public init(content: [InlineNode]) {
        self.content = content
    }
}

// Convenience typealiases for backward compatibility
public typealias TableRow = MarkdownTableRow
public typealias TableCell = MarkdownTableCell
public typealias TableColumnAlignment = MarkdownTableColumnAlignment

// MARK: - BlockNode

// MARK: - IdentifiedBlock

/// A block node paired with a stable identity suitable for SwiftUI `ForEach`.
/// The ID is derived from content hash + occurrence index, so it remains stable
/// across re-parses as long as the block content doesn't change.
public struct IdentifiedBlock: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let block: BlockNode

    public init(id: String, block: BlockNode) {
        self.id = id
        self.block = block
    }

    /// Assign stable identities to an array of blocks.
    /// Uses each block's hash value plus an occurrence counter as a tiebreaker
    /// for duplicate blocks.
    public static func identify(_ blocks: [BlockNode]) -> [IdentifiedBlock] {
        var counts: [Int: Int] = [:]
        return blocks.map { block in
            let hash = block.hashValue
            let count = counts[hash, default: 0]
            counts[hash] = count + 1
            let id = "\(hash)-\(count)"
            return IdentifiedBlock(id: id, block: block)
        }
    }
}

public indirect enum BlockNode: Equatable, Hashable, Sendable {
    case document([BlockNode])
    case heading(level: Int, content: [InlineNode])
    case paragraph(content: [InlineNode])
    case codeBlock(language: String?, content: String)
    case blockQuote(children: [BlockNode])
    case orderedList(startIndex: Int, tight: Bool, items: [ListItem])
    case unorderedList(tight: Bool, items: [ListItem])
    case table(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow])
    case thematicBreak
    case htmlBlock(content: String)
    case customBlock(name: String, content: String)
    case latexBlock(content: String)
    case blockDirective(name: String, arguments: String?, children: [BlockNode])
}
