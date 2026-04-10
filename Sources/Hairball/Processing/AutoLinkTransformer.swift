import Foundation

/// Transforms raw URLs in text nodes into proper `.link` inline nodes.
///
/// Detects `http://`, `https://`, and `mailto:` URLs within `.text()` nodes,
/// splits the text at URL boundaries, and creates `.link` nodes for each URL.
public struct AutoLinkTransformer: MarkdownProcessor {

    public init() {}

    public func process(_ document: Document) -> Document {
        let processedBlocks = document.blocks.map { processBlock($0) }
        return Document(blocks: processedBlocks, metadata: document.metadata)
    }

    // MARK: - Block Processing

    private func processBlock(_ block: BlockNode) -> BlockNode {
        switch block {
        case .document(let children):
            return .document(children.map { processBlock($0) })

        case .heading(let level, let content):
            return .heading(level: level, content: processInlines(content))

        case .paragraph(let content):
            return .paragraph(content: processInlines(content))

        case .blockQuote(let children):
            return .blockQuote(children: children.map { processBlock($0) })

        case .orderedList(let startIndex, let tight, let items):
            return .orderedList(startIndex: startIndex, tight: tight, items: items.map { processListItem($0) })

        case .unorderedList(let tight, let items):
            return .unorderedList(tight: tight, items: items.map { processListItem($0) })

        case .table(let alignments, let head, let body):
            let processedHead = MarkdownTableRow(cells: head.cells.map { cell in
                MarkdownTableCell(content: processInlines(cell.content))
            })
            let processedBody = body.map { row in
                MarkdownTableRow(cells: row.cells.map { cell in
                    MarkdownTableCell(content: processInlines(cell.content))
                })
            }
            return .table(columnAlignments: alignments, head: processedHead, body: processedBody)

        case .blockDirective(let name, let arguments, let children):
            return .blockDirective(name: name, arguments: arguments, children: children.map { processBlock($0) })

        default:
            return block
        }
    }

    private func processListItem(_ item: ListItem) -> ListItem {
        ListItem(
            children: item.children.map { processBlock($0) },
            checkbox: item.checkbox
        )
    }

    // MARK: - Inline Processing

    private func processInlines(_ inlines: [InlineNode]) -> [InlineNode] {
        inlines.flatMap { inline -> [InlineNode] in
            processInline(inline)
        }
    }

    private func processInline(_ inline: InlineNode) -> [InlineNode] {
        switch inline {
        case .text(let string):
            return extractLinks(from: string)

        case .emphasis(let children):
            return [.emphasis(children: processInlines(children))]

        case .strong(let children):
            return [.strong(children: processInlines(children))]

        case .strikethrough(let children):
            return [.strikethrough(children: processInlines(children))]

        // Don't process text inside existing links or code
        case .link, .inlineCode, .inlineHTML:
            return [inline]

        case .image(let source, let title, let children):
            return [.image(source: source, title: title, children: processInlines(children))]

        default:
            return [inline]
        }
    }

    // MARK: - URL Extraction

    /// URL pattern that handles common URL characters and avoids trailing punctuation.
    private static let urlPattern: String = {
        // Match http://, https://, or mailto: followed by valid URL characters
        // Stop before trailing punctuation that's likely not part of the URL
        let schemes = "(?:https?://|mailto:)"
        let urlChars = "[^\\s<>\\[\\]()]*[^\\s<>\\[\\]().,;:!?'\"\\)]"
        return schemes + urlChars
    }()

    private static let urlRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: urlPattern, options: [])
    }()

    private func extractLinks(from text: String) -> [InlineNode] {
        guard let regex = Self.urlRegex else {
            return [.text(text)]
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        if matches.isEmpty {
            return [.text(text)]
        }

        var result: [InlineNode] = []
        var lastEnd = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }

            // Text before the URL
            if lastEnd < range.lowerBound {
                let before = String(text[lastEnd..<range.lowerBound])
                if !before.isEmpty {
                    result.append(.text(before))
                }
            }

            let urlString = String(text[range])
            let displayText: String
            if urlString.hasPrefix("mailto:") {
                displayText = String(urlString.dropFirst("mailto:".count))
            } else {
                displayText = urlString
            }
            result.append(.link(destination: urlString, title: nil, children: [.text(displayText)]))
            lastEnd = range.upperBound
        }

        // Text after the last URL
        if lastEnd < text.endIndex {
            let after = String(text[lastEnd...])
            if !after.isEmpty {
                result.append(.text(after))
            }
        }

        return result
    }
}
