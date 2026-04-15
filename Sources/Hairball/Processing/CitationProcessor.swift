import Foundation

/// Processes citation markers in markdown text and converts them to `.citation` inline nodes.
///
/// Supports:
/// - Footnote-style: `[^1]`, `[^2]`
/// - CJK bracket-style: `【1†source】`, `【2†title】`
/// - Bracket-style with URL: `[1](url)` or `[1](url "title")`
public struct CitationProcessor: MarkdownProcessor {

    public init() {}

    public func process(_ document: Document) -> Document {
        var metadata = document.metadata
        var citationSources: [Int: (url: String?, title: String?)] = [:]
        let processedBlocks = document.blocks.map { block in
            processBlock(block, citationSources: &citationSources)
        }
        // Store citation count in metadata
        if !citationSources.isEmpty {
            metadata["citationCount"] = String(citationSources.count)
            for (index, source) in citationSources {
                if let url = source.url {
                    metadata["citation.\(index).url"] = url
                }
                if let title = source.title {
                    metadata["citation.\(index).title"] = title
                }
            }
        }
        return Document(blocks: processedBlocks, metadata: metadata)
    }

    // MARK: - Block Processing

    private func processBlock(_ block: BlockNode, citationSources: inout [Int: (url: String?, title: String?)]) -> BlockNode {
        switch block {
        case .document(let children):
            return .document(children.map { processBlock($0, citationSources: &citationSources) })

        case .heading(let level, let content):
            return .heading(level: level, content: processInlines(content, citationSources: &citationSources))

        case .paragraph(let content):
            return .paragraph(content: processInlines(content, citationSources: &citationSources))

        case .blockQuote(let children):
            return .blockQuote(children: children.map { processBlock($0, citationSources: &citationSources) })

        case .orderedList(let startIndex, let tight, let items):
            let processed = items.map { item in
                ListItem(
                    children: item.children.map { processBlock($0, citationSources: &citationSources) },
                    checkbox: item.checkbox
                )
            }
            return .orderedList(startIndex: startIndex, tight: tight, items: processed)

        case .unorderedList(let tight, let items):
            let processed = items.map { item in
                ListItem(
                    children: item.children.map { processBlock($0, citationSources: &citationSources) },
                    checkbox: item.checkbox
                )
            }
            return .unorderedList(tight: tight, items: processed)

        case .table(let alignments, let head, let body):
            let processedHead = MarkdownTableRow(cells: head.cells.map { cell in
                MarkdownTableCell(content: processInlines(cell.content, citationSources: &citationSources))
            })
            let processedBody = body.map { row in
                MarkdownTableRow(cells: row.cells.map { cell in
                    MarkdownTableCell(content: processInlines(cell.content, citationSources: &citationSources))
                })
            }
            return .table(columnAlignments: alignments, head: processedHead, body: processedBody)

        case .blockDirective(let name, let arguments, let children):
            return .blockDirective(
                name: name,
                arguments: arguments,
                children: children.map { processBlock($0, citationSources: &citationSources) }
            )

        default:
            return block
        }
    }

    // MARK: - Inline Processing

    private func processInlines(_ inlines: [InlineNode], citationSources: inout [Int: (url: String?, title: String?)]) -> [InlineNode] {
        inlines.flatMap { inline -> [InlineNode] in
            processInline(inline, citationSources: &citationSources)
        }
    }

    private func processInline(_ inline: InlineNode, citationSources: inout [Int: (url: String?, title: String?)]) -> [InlineNode] {
        switch inline {
        case .text(let string):
            return parseCitations(from: string, citationSources: &citationSources)

        case .emphasis(let children):
            return [.emphasis(children: processInlines(children, citationSources: &citationSources))]

        case .strong(let children):
            return [.strong(children: processInlines(children, citationSources: &citationSources))]

        case .strikethrough(let children):
            return [.strikethrough(children: processInlines(children, citationSources: &citationSources))]

        case .link(let dest, let title, let children):
            if let citation = parseBracketCitationLink(
                destination: dest,
                title: title,
                children: children,
                citationSources: &citationSources
            ) {
                return [citation]
            }
            return [.link(destination: dest, title: title, children: processInlines(children, citationSources: &citationSources))]

        case .image(let source, let title, let children):
            return [.image(source: source, title: title, children: processInlines(children, citationSources: &citationSources))]

        default:
            return [inline]
        }
    }

    // MARK: - Citation Parsing

    private func parseCitations(from text: String, citationSources: inout [Int: (url: String?, title: String?)]) -> [InlineNode] {
        var result: [InlineNode] = []
        var remaining = text[...]

        while !remaining.isEmpty {
            // Try to find the next citation pattern
            if let match = findNextCitation(in: remaining) {
                // Add any text before the citation
                let before = remaining[remaining.startIndex..<match.range.lowerBound]
                if !before.isEmpty {
                    result.append(.text(String(before)))
                }

                citationSources[match.index] = (url: match.url, title: match.title)
                result.append(.citation(index: match.index, url: match.url, title: match.title))
                remaining = remaining[match.range.upperBound...]
            } else {
                // No more citations
                result.append(.text(String(remaining)))
                break
            }
        }

        return result
    }

    private struct CitationMatch {
        let index: Int
        let url: String?
        let title: String?
        let range: Range<Substring.Index>
    }

    private func findNextCitation(in text: Substring) -> CitationMatch? {
        var earliest: CitationMatch? = nil

        // Pattern 1: Footnote-style [^N]
        if let match = findFootnoteCitation(in: text) {
            if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }

        // Pattern 2: CJK bracket-style 【N†source】
        if let match = findCJKBracketCitation(in: text) {
            if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }

        // Pattern 3: Bracket-style [N](url) or [N](url "title")
        if let match = findBracketCitation(in: text) {
            if earliest == nil || match.range.lowerBound < earliest!.range.lowerBound {
                earliest = match
            }
        }

        return earliest
    }

    /// Matches `[^N]` where N is one or more digits
    private func findFootnoteCitation(in text: Substring) -> CitationMatch? {
        guard let regex = try? NSRegularExpression(pattern: "\\[\\^(\\d+)\\]") else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let nsMatch = regex.firstMatch(in: String(text), range: nsRange) else { return nil }
        guard let wholeRange = Range(nsMatch.range, in: text),
              let indexRange = Range(nsMatch.range(at: 1), in: text),
              let index = Int(text[indexRange]) else { return nil }
        return CitationMatch(index: index, url: nil, title: nil, range: wholeRange)
    }

    /// Matches `【N†source】` where N is digits and source is optional text
    private func findCJKBracketCitation(in text: Substring) -> CitationMatch? {
        guard let regex = try? NSRegularExpression(pattern: "【(\\d+)†([^】]*)】") else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let nsMatch = regex.firstMatch(in: String(text), range: nsRange) else { return nil }
        guard let wholeRange = Range(nsMatch.range, in: text),
              let indexRange = Range(nsMatch.range(at: 1), in: text),
              let index = Int(text[indexRange]) else { return nil }

        var title: String? = nil
        if let titleRange = Range(nsMatch.range(at: 2), in: text) {
            let t = String(text[titleRange])
            if !t.isEmpty { title = t }
        }
        return CitationMatch(index: index, url: nil, title: title, range: wholeRange)
    }

    /// Matches `[N](url)` or `[N](url "title")` where N is digits
    private func findBracketCitation(in text: Substring) -> CitationMatch? {
        // Pattern: [digits](url) or [digits](url "title")
        guard let regex = try? NSRegularExpression(
            pattern: "\\[(\\d+)\\]\\(([^\\s\\)]+)(?:\\s+\"([^\"]*)\")?\\ *\\)"
        ) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let nsMatch = regex.firstMatch(in: String(text), range: nsRange) else { return nil }
        guard let wholeRange = Range(nsMatch.range, in: text),
              let indexRange = Range(nsMatch.range(at: 1), in: text),
              let index = Int(text[indexRange]) else { return nil }

        var url: String? = nil
        if let urlRange = Range(nsMatch.range(at: 2), in: text) {
            url = String(text[urlRange])
        }

        var title: String? = nil
        if nsMatch.range(at: 3).location != NSNotFound,
           let titleRange = Range(nsMatch.range(at: 3), in: text) {
            title = String(text[titleRange])
        }

        return CitationMatch(index: index, url: url, title: title, range: wholeRange)
    }

    private func parseBracketCitationLink(
        destination: String,
        title: String?,
        children: [InlineNode],
        citationSources: inout [Int: (url: String?, title: String?)]
    ) -> InlineNode? {
        let text = children.compactMap { node -> String? in
            if case .text(let value) = node { return value }
            return nil
        }.joined()

        guard !text.isEmpty, text.range(of: #"^\d+$"#, options: .regularExpression) != nil,
              let index = Int(text) else {
            return nil
        }

        citationSources[index] = (url: destination, title: title)
        return .citation(index: index, url: destination, title: title)
    }
}
