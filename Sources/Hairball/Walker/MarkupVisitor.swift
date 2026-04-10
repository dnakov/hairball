import Foundation

public protocol MarkupVisitor {
    associatedtype Result = Void

    func defaultVisit(block: BlockNode) -> Result
    func defaultVisit(inline: InlineNode) -> Result

    // MARK: - Block visitors

    func visitDocument(_ children: [BlockNode]) -> Result
    func visitHeading(level: Int, content: [InlineNode]) -> Result
    func visitParagraph(content: [InlineNode]) -> Result
    func visitCodeBlock(language: String?, content: String) -> Result
    func visitBlockQuote(children: [BlockNode]) -> Result
    func visitOrderedList(startIndex: Int, tight: Bool, items: [ListItem]) -> Result
    func visitUnorderedList(tight: Bool, items: [ListItem]) -> Result
    func visitTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow]) -> Result
    func visitThematicBreak() -> Result
    func visitHTMLBlock(content: String) -> Result
    func visitCustomBlock(name: String, content: String) -> Result
    func visitLatexBlock(content: String) -> Result
    func visitBlockDirective(name: String, arguments: String?, children: [BlockNode]) -> Result

    // MARK: - Inline visitors

    func visitText(_ text: String) -> Result
    func visitEmphasis(children: [InlineNode]) -> Result
    func visitStrong(children: [InlineNode]) -> Result
    func visitStrikethrough(children: [InlineNode]) -> Result
    func visitInlineCode(_ code: String) -> Result
    func visitLink(destination: String, title: String?, children: [InlineNode]) -> Result
    func visitImage(source: String, title: String?, children: [InlineNode]) -> Result
    func visitSoftBreak() -> Result
    func visitHardBreak() -> Result
    func visitLineBreak() -> Result
    func visitInlineHTML(_ html: String) -> Result
    func visitLatex(content: String) -> Result
    func visitCitation(index: Int, url: String?, title: String?) -> Result
    func visitCustomInline(name: String, content: String) -> Result
}

// MARK: - Default implementations for Void result

public extension MarkupVisitor where Result == Void {
    func defaultVisit(block: BlockNode) {}
    func defaultVisit(inline: InlineNode) {}

    func visitDocument(_ children: [BlockNode]) { defaultVisit(block: .document(children)) }
    func visitHeading(level: Int, content: [InlineNode]) { defaultVisit(block: .heading(level: level, content: content)) }
    func visitParagraph(content: [InlineNode]) { defaultVisit(block: .paragraph(content: content)) }
    func visitCodeBlock(language: String?, content: String) { defaultVisit(block: .codeBlock(language: language, content: content)) }
    func visitBlockQuote(children: [BlockNode]) { defaultVisit(block: .blockQuote(children: children)) }
    func visitOrderedList(startIndex: Int, tight: Bool, items: [ListItem]) { defaultVisit(block: .orderedList(startIndex: startIndex, tight: tight, items: items)) }
    func visitUnorderedList(tight: Bool, items: [ListItem]) { defaultVisit(block: .unorderedList(tight: tight, items: items)) }
    func visitTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow]) { defaultVisit(block: .table(columnAlignments: columnAlignments, head: head, body: body)) }
    func visitThematicBreak() { defaultVisit(block: .thematicBreak) }
    func visitHTMLBlock(content: String) { defaultVisit(block: .htmlBlock(content: content)) }
    func visitCustomBlock(name: String, content: String) { defaultVisit(block: .customBlock(name: name, content: content)) }
    func visitLatexBlock(content: String) { defaultVisit(block: .latexBlock(content: content)) }
    func visitBlockDirective(name: String, arguments: String?, children: [BlockNode]) { defaultVisit(block: .blockDirective(name: name, arguments: arguments, children: children)) }

    func visitText(_ text: String) { defaultVisit(inline: .text(text)) }
    func visitEmphasis(children: [InlineNode]) { defaultVisit(inline: .emphasis(children: children)) }
    func visitStrong(children: [InlineNode]) { defaultVisit(inline: .strong(children: children)) }
    func visitStrikethrough(children: [InlineNode]) { defaultVisit(inline: .strikethrough(children: children)) }
    func visitInlineCode(_ code: String) { defaultVisit(inline: .inlineCode(code)) }
    func visitLink(destination: String, title: String?, children: [InlineNode]) { defaultVisit(inline: .link(destination: destination, title: title, children: children)) }
    func visitImage(source: String, title: String?, children: [InlineNode]) { defaultVisit(inline: .image(source: source, title: title, children: children)) }
    func visitSoftBreak() { defaultVisit(inline: .softBreak) }
    func visitHardBreak() { defaultVisit(inline: .hardBreak) }
    func visitLineBreak() { defaultVisit(inline: .lineBreak) }
    func visitInlineHTML(_ html: String) { defaultVisit(inline: .inlineHTML(html)) }
    func visitLatex(content: String) { defaultVisit(inline: .latex(content: content)) }
    func visitCitation(index: Int, url: String?, title: String?) { defaultVisit(inline: .citation(index: index, url: url, title: title)) }
    func visitCustomInline(name: String, content: String) { defaultVisit(inline: .customInline(name: name, content: content)) }
}
