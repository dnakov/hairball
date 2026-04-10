import Foundation

public struct Document: Equatable, Hashable, Sendable {
    public var blocks: [BlockNode]
    public var metadata: [String: String]

    public init(blocks: [BlockNode], metadata: [String: String] = [:]) {
        self.blocks = blocks
        self.metadata = metadata
    }

    public var plainText: String {
        blocks.map { plainText(from: $0) }.joined(separator: "\n")
    }

    // MARK: - Private helpers

    private func plainText(from block: BlockNode) -> String {
        switch block {
        case .document(let children):
            return children.map { plainText(from: $0) }.joined(separator: "\n")
        case .heading(_, let content):
            return content.map { plainText(from: $0) }.joined()
        case .paragraph(let content):
            return content.map { plainText(from: $0) }.joined()
        case .codeBlock(_, let content):
            return content
        case .blockQuote(let children):
            return children.map { plainText(from: $0) }.joined(separator: "\n")
        case .orderedList(_, _, let items):
            return items.map { item in
                item.children.map { plainText(from: $0) }.joined(separator: "\n")
            }.joined(separator: "\n")
        case .unorderedList(_, let items):
            return items.map { item in
                item.children.map { plainText(from: $0) }.joined(separator: "\n")
            }.joined(separator: "\n")
        case .table(_, let head, let body):
            let headText = head.cells.map { cell in
                cell.content.map { plainText(from: $0) }.joined()
            }.joined(separator: "\t")
            let bodyText = body.map { row in
                row.cells.map { cell in
                    cell.content.map { plainText(from: $0) }.joined()
                }.joined(separator: "\t")
            }.joined(separator: "\n")
            return headText.isEmpty ? bodyText : headText + "\n" + bodyText
        case .thematicBreak:
            return ""
        case .htmlBlock(let content):
            return content
        case .customBlock(_, let content):
            return content
        case .latexBlock(let content):
            return content
        case .blockDirective(_, _, let children):
            return children.map { plainText(from: $0) }.joined(separator: "\n")
        }
    }

    private func plainText(from inline: InlineNode) -> String {
        switch inline {
        case .text(let string):
            return string
        case .emphasis(let children):
            return children.map { plainText(from: $0) }.joined()
        case .strong(let children):
            return children.map { plainText(from: $0) }.joined()
        case .strikethrough(let children):
            return children.map { plainText(from: $0) }.joined()
        case .inlineCode(let string):
            return string
        case .link(_, _, let children):
            return children.map { plainText(from: $0) }.joined()
        case .image(_, _, let children):
            return children.map { plainText(from: $0) }.joined()
        case .softBreak:
            return " "
        case .hardBreak, .lineBreak:
            return "\n"
        case .inlineHTML(let string):
            return string
        case .latex(let content):
            return content
        case .citation(_, _, let title):
            return title ?? ""
        case .customInline(_, let content):
            return content
        }
    }
}
