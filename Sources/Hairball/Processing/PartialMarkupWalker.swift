import Foundation

// MARK: - PartialMarkupWalker Protocol

/// A protocol for walking a partial/incomplete markup tree.
/// Used during streaming to process nodes that may be incomplete.
public protocol PartialMarkupWalker {
    mutating func visitDocument(_ blocks: [BlockNode], isComplete: Bool)
    mutating func visitBlock(_ block: BlockNode, isComplete: Bool)
    mutating func visitInline(_ inline: InlineNode, isComplete: Bool)
}

/// Default implementations that walk the full tree.
extension PartialMarkupWalker {
    public mutating func visitDocument(_ blocks: [BlockNode], isComplete: Bool) {
        for (index, block) in blocks.enumerated() {
            let blockComplete = isComplete || index < blocks.count - 1
            visitBlock(block, isComplete: blockComplete)
        }
    }

    public mutating func visitBlock(_ block: BlockNode, isComplete: Bool) {
        switch block {
        case .document(let children):
            visitDocument(children, isComplete: isComplete)
        case .heading(_, let content):
            walkInlines(content, isComplete: isComplete)
        case .paragraph(let content):
            walkInlines(content, isComplete: isComplete)
        case .blockQuote(let children):
            for (i, child) in children.enumerated() {
                visitBlock(child, isComplete: isComplete || i < children.count - 1)
            }
        case .orderedList(_, _, let items):
            for (i, item) in items.enumerated() {
                let itemComplete = isComplete || i < items.count - 1
                for (j, child) in item.children.enumerated() {
                    visitBlock(child, isComplete: itemComplete || j < item.children.count - 1)
                }
            }
        case .unorderedList(_, let items):
            for (i, item) in items.enumerated() {
                let itemComplete = isComplete || i < items.count - 1
                for (j, child) in item.children.enumerated() {
                    visitBlock(child, isComplete: itemComplete || j < item.children.count - 1)
                }
            }
        case .table(_, let head, let body):
            for cell in head.cells {
                walkInlines(cell.content, isComplete: isComplete)
            }
            for row in body {
                for cell in row.cells {
                    walkInlines(cell.content, isComplete: isComplete)
                }
            }
        default:
            break
        }
    }

    private mutating func walkInlines(_ inlines: [InlineNode], isComplete: Bool) {
        for (i, inline) in inlines.enumerated() {
            let nodeComplete = isComplete || i < inlines.count - 1
            visitInline(inline, isComplete: nodeComplete)
        }
    }

    public mutating func visitInline(_ inline: InlineNode, isComplete: Bool) {
        switch inline {
        case .emphasis(let children), .strong(let children), .strikethrough(let children):
            walkInlines(children, isComplete: isComplete)
        case .link(_, _, let children), .image(_, _, let children):
            walkInlines(children, isComplete: isComplete)
        default:
            break
        }
    }
}

// MARK: - PartialMarkupTreeBuilder

/// Incrementally builds a markdown AST as text arrives in chunks.
/// Supports appending text and querying the current (possibly incomplete) document state.
public final class PartialMarkupTreeBuilder: @unchecked Sendable {

    private var buffer: String = ""
    private var _currentDocument: Document
    private let lock = NSLock()
    private var lastParsedLength: Int = 0
    /// Cached stable blocks parsed from content before the last blank-line boundary.
    private var stableBlocks: [BlockNode] = []
    /// The buffer length up to which stable blocks have been finalized.
    private var stableEndOffset: Int = 0

    public init() {
        _currentDocument = Document(blocks: [])
    }

    /// Append more markdown text (streaming chunk).
    public func append(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(text)
        // Skip re-parse if nothing actually changed (e.g. empty append or duplicate call).
        guard buffer.count != lastParsedLength else { return }
        reparseIncremental()
    }

    /// Replace all content with new text.
    public func reset(with text: String = "") {
        lock.lock()
        defer { lock.unlock() }
        buffer = text
        lastParsedLength = 0
        stableBlocks = []
        stableEndOffset = 0
        _currentDocument = text.isEmpty ? Document(blocks: []) : parsePartial(buffer)
        lastParsedLength = buffer.count
    }

    /// Re-parse only from the last stable block boundary (blank line) for incremental performance.
    private func reparseIncremental() {
        // Find the last double-newline boundary in the buffer — content before it is "stable"
        // (complete blocks that won't change with further appends).
        let bufferCount = buffer.count
        if let lastBlankRange = buffer.range(of: "\n\n", options: .backwards) {
            let boundaryOffset = buffer.distance(from: buffer.startIndex, to: lastBlankRange.upperBound)
            if boundaryOffset > stableEndOffset {
                // Parse the newly-stable prefix to update stableBlocks.
                let stableText = String(buffer[buffer.startIndex..<lastBlankRange.upperBound])
                let stableDoc = parsePartial(stableText)
                stableBlocks = stableDoc.blocks
                stableEndOffset = boundaryOffset
            }
            // Parse only the trailing (unstable) portion.
            let tailStart = buffer.index(buffer.startIndex, offsetBy: stableEndOffset)
            let tail = String(buffer[tailStart...])
            let tailTrimmed = tail.trimmingCharacters(in: .whitespacesAndNewlines)
            if tailTrimmed.isEmpty {
                _currentDocument = Document(blocks: stableBlocks)
            } else {
                let tailDoc = parsePartial(tail)
                _currentDocument = Document(blocks: stableBlocks + tailDoc.blocks)
            }
        } else {
            // No blank-line boundary yet — full re-parse (small buffer).
            _currentDocument = parsePartial(buffer)
        }
        lastParsedLength = bufferCount
    }

    /// The current (possibly incomplete) document.
    public var currentDocument: Document {
        lock.lock()
        defer { lock.unlock() }
        return _currentDocument
    }

    /// The raw text buffer accumulated so far.
    public var currentText: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    // MARK: - Partial Parsing

    /// Parses markdown text into a Document, gracefully handling incomplete constructs.
    private func parsePartial(_ text: String) -> Document {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [BlockNode] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Blank line - skip
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Heading: # ...
            if let heading = parseHeading(line) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Thematic break: ---, ***, ___
            if isThematicBreak(line) {
                blocks.append(.thematicBreak)
                i += 1
                continue
            }

            // Fenced code block: ```
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                let (codeBlock, nextIndex) = parseFencedCodeBlock(lines: lines, startIndex: i)
                blocks.append(codeBlock)
                i = nextIndex
                continue
            }

            // Block quote: >
            if line.hasPrefix(">") || line.hasPrefix(" >") {
                let (blockQuote, nextIndex) = parseBlockQuote(lines: lines, startIndex: i)
                blocks.append(blockQuote)
                i = nextIndex
                continue
            }

            // Unordered list: - or * or +
            if isUnorderedListItem(line) {
                let (list, nextIndex) = parseUnorderedList(lines: lines, startIndex: i)
                blocks.append(list)
                i = nextIndex
                continue
            }

            // Ordered list: 1. 2. etc.
            if isOrderedListItem(line) {
                let (list, nextIndex) = parseOrderedList(lines: lines, startIndex: i)
                blocks.append(list)
                i = nextIndex
                continue
            }

            // Display math: $$ ... $$
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("$$") {
                let (mathBlock, nextIndex) = parseDisplayMath(lines: lines, startIndex: i)
                blocks.append(mathBlock)
                i = nextIndex
                continue
            }

            // Default: paragraph
            let (paragraph, nextIndex) = parseParagraph(lines: lines, startIndex: i)
            blocks.append(paragraph)
            i = nextIndex
        }

        return Document(blocks: blocks)
    }

    // MARK: - Line-Level Parsers

    private func parseHeading(_ line: String) -> BlockNode? {
        let trimmed = line.drop(while: { $0 == " " })
        var level = 0
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex && trimmed[idx] == "#" && level < 6 {
            level += 1
            idx = trimmed.index(after: idx)
        }
        guard level > 0 else { return nil }
        // Must have space after # or be end of line
        if idx < trimmed.endIndex && trimmed[idx] != " " { return nil }

        let content: String
        if idx < trimmed.endIndex {
            content = String(trimmed[trimmed.index(after: idx)...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            content = ""
        }
        return .heading(level: level, content: content.isEmpty ? [] : [.text(content)])
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        let chars = Set(trimmed.filter { $0 != " " })
        return chars.count == 1 && (chars.contains("-") || chars.contains("*") || chars.contains("_"))
    }

    private func parseFencedCodeBlock(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        let openLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let language = String(openLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let lang: String? = language.isEmpty ? nil : language

        var content: [String] = []
        var i = startIndex + 1

        while i < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // Closing fence found
                return (.codeBlock(language: lang, content: content.joined(separator: "\n")), i + 1)
            }
            content.append(lines[i])
            i += 1
        }

        // Unclosed code block - still return what we have (partial/streaming)
        return (.codeBlock(language: lang, content: content.joined(separator: "\n")), i)
    }

    private func parseBlockQuote(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        var quoteLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix(">") {
                let stripped = String(line.dropFirst(line.hasPrefix("> ") ? 2 : 1))
                quoteLines.append(stripped)
                i += 1
            } else if line.hasPrefix(" >") {
                let stripped = line.trimmingCharacters(in: .whitespaces)
                if stripped.hasPrefix(">") {
                    let content = String(stripped.dropFirst(stripped.hasPrefix("> ") ? 2 : 1))
                    quoteLines.append(content)
                    i += 1
                } else {
                    break
                }
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            } else {
                // Lazy continuation
                quoteLines.append(line)
                i += 1
            }
        }

        // Recursively parse the quote content
        let innerText = quoteLines.joined(separator: "\n")
        let innerDoc = parsePartial(innerText)
        return (.blockQuote(children: innerDoc.blocks), i)
    }

    private func isUnorderedListItem(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmed.first else { return false }
        if (first == "-" || first == "*" || first == "+") {
            let afterMarker = trimmed.dropFirst()
            return afterMarker.isEmpty || afterMarker.first == " "
        }
        return false
    }

    private func isOrderedListItem(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex && trimmed[idx].isNumber {
            idx = trimmed.index(after: idx)
        }
        guard idx > trimmed.startIndex && idx < trimmed.endIndex else { return false }
        return (trimmed[idx] == "." || trimmed[idx] == ")") &&
               (trimmed.index(after: idx) >= trimmed.endIndex || trimmed[trimmed.index(after: idx)] == " ")
    }

    private func parseUnorderedList(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        var items: [ListItem] = []
        var i = startIndex

        while i < lines.count && (isUnorderedListItem(lines[i]) || isListContinuation(lines[i])) {
            if isUnorderedListItem(lines[i]) {
                let content = extractListItemContent(lines[i])
                var itemLines = [content]
                i += 1
                // Gather continuation lines
                while i < lines.count && isListContinuation(lines[i]) && !isUnorderedListItem(lines[i]) {
                    itemLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                let text = itemLines.joined(separator: " ")
                let checkbox = parseCheckbox(text)
                let actualText = checkbox != nil ? String(text.dropFirst(text.hasPrefix("[ ] ") || text.hasPrefix("[x] ") || text.hasPrefix("[X] ") ? 4 : 0)) : text
                items.append(ListItem(
                    children: actualText.isEmpty ? [] : [.paragraph(content: [.text(actualText)])],
                    checkbox: checkbox
                ))
            } else {
                i += 1
            }
        }

        return (.unorderedList(tight: true, items: items), i)
    }

    private func parseOrderedList(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        var items: [ListItem] = []
        var i = startIndex
        var startNum = 1

        if let num = extractOrderedListNumber(lines[startIndex]) {
            startNum = num
        }

        while i < lines.count && (isOrderedListItem(lines[i]) || isListContinuation(lines[i])) {
            if isOrderedListItem(lines[i]) {
                let content = extractOrderedListContent(lines[i])
                var itemLines = [content]
                i += 1
                while i < lines.count && isListContinuation(lines[i]) && !isOrderedListItem(lines[i]) {
                    itemLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                let text = itemLines.joined(separator: " ")
                items.append(ListItem(
                    children: text.isEmpty ? [] : [.paragraph(content: [.text(text)])]
                ))
            } else {
                i += 1
            }
        }

        return (.orderedList(startIndex: startNum, tight: true, items: items), i)
    }

    private func parseParagraph(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        var paraLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at blank line or block-level construct
            if trimmed.isEmpty { break }
            if trimmed.hasPrefix("#") { break }
            if trimmed.hasPrefix("```") { break }
            if trimmed.hasPrefix(">") { break }
            if isThematicBreak(line) { break }
            if isUnorderedListItem(line) && !paraLines.isEmpty { break }
            if isOrderedListItem(line) && !paraLines.isEmpty { break }
            if trimmed.hasPrefix("$$") && !paraLines.isEmpty { break }

            paraLines.append(trimmed)
            i += 1
        }

        let text = paraLines.joined(separator: " ")
        return (.paragraph(content: text.isEmpty ? [] : [.text(text)]), i)
    }

    private func parseDisplayMath(lines: [String], startIndex: Int) -> (BlockNode, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        var content: [String] = []
        var i = startIndex

        // Check if $$ content $$ is on the same line
        if firstLine.hasPrefix("$$") && firstLine.dropFirst(2).contains("$$") {
            let inner = String(firstLine.dropFirst(2))
            if let endRange = inner.range(of: "$$") {
                let mathContent = String(inner[inner.startIndex..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (.latexBlock(content: mathContent), startIndex + 1)
            }
        }

        // Multi-line $$
        i = startIndex + 1
        let afterOpener = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        if !afterOpener.isEmpty {
            content.append(afterOpener)
        }

        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).hasSuffix("$$") ||
               line.trimmingCharacters(in: .whitespaces) == "$$" {
                let beforeClose = line.trimmingCharacters(in: .whitespaces)
                if beforeClose != "$$" {
                    content.append(String(beforeClose.dropLast(2)).trimmingCharacters(in: .whitespaces))
                }
                return (.latexBlock(content: content.joined(separator: "\n")), i + 1)
            }
            content.append(line)
            i += 1
        }

        // Unclosed - return what we have (partial/streaming)
        return (.latexBlock(content: content.joined(separator: "\n")), i)
    }

    // MARK: - Helpers

    private func isListContinuation(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        // Indented continuation or next list item
        return line.hasPrefix("  ") || line.hasPrefix("\t") || isUnorderedListItem(line) || isOrderedListItem(line)
    }

    private func extractListItemContent(_ line: String) -> String {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        // Drop marker (-, *, +) and following space
        let afterMarker = trimmed.dropFirst(1)
        if afterMarker.first == " " {
            return String(afterMarker.dropFirst(1))
        }
        return String(afterMarker)
    }

    private func extractOrderedListNumber(_ line: String) -> Int? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        var numStr = ""
        for ch in trimmed {
            if ch.isNumber { numStr.append(ch) }
            else { break }
        }
        return Int(numStr)
    }

    private func extractOrderedListContent(_ line: String) -> String {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        // Skip digits, then . or ), then space
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex && trimmed[idx].isNumber {
            idx = trimmed.index(after: idx)
        }
        if idx < trimmed.endIndex && (trimmed[idx] == "." || trimmed[idx] == ")") {
            idx = trimmed.index(after: idx)
        }
        if idx < trimmed.endIndex && trimmed[idx] == " " {
            idx = trimmed.index(after: idx)
        }
        return String(trimmed[idx...])
    }

    private func parseCheckbox(_ text: String) -> CheckboxState? {
        if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
            return .checked
        }
        if text.hasPrefix("[ ] ") {
            return .unchecked
        }
        return nil
    }
}
