import Foundation

/// The default processor that normalizes whitespace, trims empty blocks,
/// and merges adjacent text nodes within inline content.
public struct DefaultMarkdownProcessor: MarkdownProcessor {

    public init() {}

    public func process(_ document: Document) -> Document {
        let processed = document.blocks.compactMap { processBlock($0) }
        return Document(blocks: processed, metadata: document.metadata)
    }

    // MARK: - Block Processing

    private func processBlock(_ block: BlockNode) -> BlockNode? {
        switch block {
        case .document(let children):
            let processed = children.compactMap { processBlock($0) }
            return processed.isEmpty ? nil : .document(processed)

        case .heading(let level, let content):
            let merged = mergeTextNodes(normalizeInlines(content))
            return merged.isEmpty ? nil : .heading(level: level, content: merged)

        case .paragraph(let content):
            let merged = mergeTextNodes(normalizeInlines(content))
            return merged.isEmpty ? nil : .paragraph(content: merged)

        case .codeBlock(let language, let content):
            // Preserve code block content as-is, but trim trailing newlines
            let trimmed = content.replacingOccurrences(
                of: "\\n+$", with: "\n", options: .regularExpression
            )
            return .codeBlock(language: language, content: trimmed)

        case .blockQuote(let children):
            let processed = children.compactMap { processBlock($0) }
            return processed.isEmpty ? nil : .blockQuote(children: processed)

        case .orderedList(let startIndex, let tight, let items):
            let processed = items.compactMap { processListItem($0) }
            return processed.isEmpty ? nil : .orderedList(startIndex: startIndex, tight: tight, items: processed)

        case .unorderedList(let tight, let items):
            let processed = items.compactMap { processListItem($0) }
            return processed.isEmpty ? nil : .unorderedList(tight: tight, items: processed)

        case .table(let alignments, let head, let body):
            let processedHead = processMarkdownTableRow(head)
            let processedBody = body.map { processMarkdownTableRow($0) }
            return .table(columnAlignments: alignments, head: processedHead, body: processedBody)

        case .thematicBreak:
            return .thematicBreak

        case .htmlBlock(let content):
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .htmlBlock(content: trimmed)

        case .customBlock(let name, let content):
            return .customBlock(name: name, content: content)

        case .latexBlock(let content):
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .latexBlock(content: trimmed)

        case .blockDirective(let name, let arguments, let children):
            let processed = children.compactMap { processBlock($0) }
            return .blockDirective(name: name, arguments: arguments, children: processed)
        }
    }

    private func processListItem(_ item: ListItem) -> ListItem? {
        let processed = item.children.compactMap { processBlock($0) }
        if processed.isEmpty { return nil }
        return ListItem(children: processed, checkbox: item.checkbox)
    }

    private func processMarkdownTableRow(_ row: MarkdownTableRow) -> MarkdownTableRow {
        MarkdownTableRow(cells: row.cells.map { cell in
            MarkdownTableCell(content: mergeTextNodes(normalizeInlines(cell.content)))
        })
    }

    // MARK: - Inline Processing

    private func normalizeInlines(_ inlines: [InlineNode]) -> [InlineNode] {
        inlines.compactMap { normalizeInline($0) }
    }

    private func normalizeInline(_ inline: InlineNode) -> InlineNode? {
        switch inline {
        case .text(let string):
            let normalized = normalizeWhitespace(string)
            return normalized.isEmpty ? nil : .text(normalized)

        case .emphasis(let children):
            let processed = mergeTextNodes(normalizeInlines(children))
            return processed.isEmpty ? nil : .emphasis(children: processed)

        case .strong(let children):
            let processed = mergeTextNodes(normalizeInlines(children))
            return processed.isEmpty ? nil : .strong(children: processed)

        case .strikethrough(let children):
            let processed = mergeTextNodes(normalizeInlines(children))
            return processed.isEmpty ? nil : .strikethrough(children: processed)

        case .link(let dest, let title, let children):
            let processed = mergeTextNodes(normalizeInlines(children))
            return .link(destination: dest, title: title, children: processed)

        case .image(let source, let title, let children):
            let processed = mergeTextNodes(normalizeInlines(children))
            return .image(source: source, title: title, children: processed)

        default:
            return inline
        }
    }

    // MARK: - Text Merging

    /// Merges adjacent `.text` nodes into a single node.
    private func mergeTextNodes(_ inlines: [InlineNode]) -> [InlineNode] {
        var result: [InlineNode] = []
        var pendingText: String? = nil

        for node in inlines {
            if case .text(let string) = node {
                if pendingText != nil {
                    pendingText!.append(string)
                } else {
                    pendingText = string
                }
            } else {
                if let text = pendingText {
                    result.append(.text(text))
                    pendingText = nil
                }
                result.append(node)
            }
        }

        if let text = pendingText {
            result.append(.text(text))
        }

        return result
    }

    // MARK: - Whitespace Normalization

    private func normalizeWhitespace(_ string: String) -> String {
        // Collapse runs of whitespace (spaces, tabs) into single spaces.
        // Preserve leading/trailing single spaces but remove pure-whitespace strings.
        let collapsed = string.replacingOccurrences(
            of: "[ \\t]+", with: " ", options: .regularExpression
        )
        return collapsed
    }
}
