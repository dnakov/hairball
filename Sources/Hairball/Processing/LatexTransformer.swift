import Foundation

/// Transforms LaTeX delimiters in text into structured latex nodes.
///
/// Handles:
/// - Inline math: `$...$` and `\(...\)` → `.latex(content:)` inline nodes
/// - Display/block math: `$$...$$` and `\[...\]` → `.latexBlock(content:)` block nodes
/// - Escape handling: `\$` does not trigger math mode
public struct LatexTransformer: MarkdownProcessor {

    public init() {}

    public func process(_ document: Document) -> Document {
        let processedBlocks = document.blocks.flatMap { processBlockForLatex($0) }
        return Document(blocks: processedBlocks, metadata: document.metadata)
    }

    // MARK: - Block Processing

    private func processBlockForLatex(_ block: BlockNode) -> [BlockNode] {
        switch block {
        case .document(let children):
            return [.document(children.flatMap { processBlockForLatex($0) })]

        case .heading(let level, let content):
            return [.heading(level: level, content: processInlines(content))]

        case .paragraph(let content):
            // A paragraph might contain display math that should become a latexBlock.
            return processParagraphForDisplayMath(content)

        case .blockQuote(let children):
            return [.blockQuote(children: children.flatMap { processBlockForLatex($0) })]

        case .orderedList(let startIndex, let tight, let items):
            let processed = items.map { item in
                ListItem(
                    children: item.children.flatMap { processBlockForLatex($0) },
                    checkbox: item.checkbox
                )
            }
            return [.orderedList(startIndex: startIndex, tight: tight, items: processed)]

        case .unorderedList(let tight, let items):
            let processed = items.map { item in
                ListItem(
                    children: item.children.flatMap { processBlockForLatex($0) },
                    checkbox: item.checkbox
                )
            }
            return [.unorderedList(tight: tight, items: processed)]

        case .table(let alignments, let head, let body):
            let processedHead = MarkdownTableRow(cells: head.cells.map { cell in
                MarkdownTableCell(content: processInlines(cell.content))
            })
            let processedBody = body.map { row in
                MarkdownTableRow(cells: row.cells.map { cell in
                    MarkdownTableCell(content: processInlines(cell.content))
                })
            }
            return [.table(columnAlignments: alignments, head: processedHead, body: processedBody)]

        case .blockDirective(let name, let arguments, let children):
            return [.blockDirective(name: name, arguments: arguments, children: children.flatMap { processBlockForLatex($0) })]

        default:
            return [block]
        }
    }

    /// Checks if a paragraph consists entirely of display math, and if so, converts to `.latexBlock`.
    private func processParagraphForDisplayMath(_ inlines: [InlineNode]) -> [BlockNode] {
        // Combine all text nodes to check for display-level math
        let fullText = inlines.compactMap { node -> String? in
            if case .text(let s) = node { return s }
            if case .softBreak = node { return "\n" }
            if case .hardBreak = node { return "\n" }
            return nil
        }.joined()

        // Check if the entire paragraph is a display math block
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check $$...$$ pattern
        if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
            let content = String(trimmed.dropFirst(2).dropLast(2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [.latexBlock(content: content)]
        }

        // Check \[...\] pattern
        if trimmed.hasPrefix("\\[") && trimmed.hasSuffix("\\]") && trimmed.count > 4 {
            let content = String(trimmed.dropFirst(2).dropLast(2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [.latexBlock(content: content)]
        }

        // Otherwise, process inline math within the paragraph
        let processed = processInlines(inlines)
        return [.paragraph(content: processed)]
    }

    // MARK: - Inline Processing

    private func processInlines(_ inlines: [InlineNode]) -> [InlineNode] {
        inlines.flatMap { processInline($0) }
    }

    private func processInline(_ inline: InlineNode) -> [InlineNode] {
        switch inline {
        case .text(let string):
            return parseInlineLatex(from: string)

        case .emphasis(let children):
            return [.emphasis(children: processInlines(children))]

        case .strong(let children):
            return [.strong(children: processInlines(children))]

        case .strikethrough(let children):
            return [.strikethrough(children: processInlines(children))]

        case .link(let dest, let title, let children):
            return [.link(destination: dest, title: title, children: processInlines(children))]

        case .image(let source, let title, let children):
            return [.image(source: source, title: title, children: processInlines(children))]

        // Don't process inside code or existing latex
        case .inlineCode, .latex, .inlineHTML:
            return [inline]

        default:
            return [inline]
        }
    }

    // MARK: - Inline LaTeX Parsing

    private func parseInlineLatex(from text: String) -> [InlineNode] {
        var result: [InlineNode] = []
        var i = text.startIndex
        var textStart = text.startIndex // tracks start of pending plain text

        func flushText(upTo end: String.Index) {
            if textStart < end {
                result.append(.text(String(text[textStart..<end])))
            }
        }

        while i < text.endIndex {
            // Check for escaped characters
            if text[i] == "\\" && text.index(after: i) < text.endIndex {
                let next = text[text.index(after: i)]

                // \$ escape - not math mode
                if next == "$" {
                    flushText(upTo: i)
                    result.append(.text("$"))
                    i = text.index(i, offsetBy: 2)
                    textStart = i
                    continue
                }

                // \(...\) inline math
                if next == "(" {
                    if let endIdx = findClosingParenEscape(in: text, from: text.index(i, offsetBy: 2)) {
                        flushText(upTo: i)
                        let content = String(text[text.index(i, offsetBy: 2)..<endIdx])
                        result.append(.latex(content: content))
                        i = text.index(endIdx, offsetBy: 2) // skip \)
                        textStart = i
                        continue
                    }
                }
            }

            // Check for $...$ inline math (not $$)
            if text[i] == "$" {
                let nextIdx = text.index(after: i)
                // Skip $$ (display math handled at block level)
                if nextIdx < text.endIndex && text[nextIdx] == "$" {
                    i = text.index(after: nextIdx)
                    continue
                }

                // Find closing $
                if let endIdx = findClosingDollar(in: text, from: nextIdx) {
                    let content = String(text[nextIdx..<endIdx])
                    if !content.isEmpty {
                        flushText(upTo: i)
                        result.append(.latex(content: content))
                        i = text.index(after: endIdx)
                        textStart = i
                        continue
                    }
                }
            }

            i = text.index(after: i)
        }

        // Remaining text
        flushText(upTo: text.endIndex)

        return result.isEmpty ? [.text(text)] : result
    }

    /// Finds `\)` closing delimiter starting from `start`.
    private func findClosingParenEscape(in text: String, from start: String.Index) -> String.Index? {
        var i = start
        while i < text.endIndex {
            if text[i] == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == ")" {
                    return i
                }
                if next < text.endIndex {
                    i = text.index(after: next)
                    continue
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    /// Finds closing `$` that is not escaped.
    private func findClosingDollar(in text: String, from start: String.Index) -> String.Index? {
        var i = start
        while i < text.endIndex {
            if text[i] == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex {
                    i = text.index(after: next) // skip escaped char
                    continue
                }
            }
            if text[i] == "$" {
                // Make sure there's actual content between delimiters
                if i > start {
                    return i
                }
                return nil
            }
            i = text.index(after: i)
        }
        return nil
    }
}
