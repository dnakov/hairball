import Foundation

open class MarkupWalker {
    public init() {}

    // MARK: - Visit methods (override in subclasses)

    open func visitDocument(_ children: [BlockNode]) {
        for child in children {
            walk(block: child)
        }
    }

    open func visitHeading(level: Int, content: [InlineNode]) {
        for node in content {
            walk(inline: node)
        }
    }

    open func visitParagraph(content: [InlineNode]) {
        for node in content {
            walk(inline: node)
        }
    }

    open func visitCodeBlock(language: String?, content: String) {}

    open func visitBlockQuote(children: [BlockNode]) {
        for child in children {
            walk(block: child)
        }
    }

    open func visitOrderedList(startIndex: Int, tight: Bool, items: [ListItem]) {
        for item in items {
            for child in item.children {
                walk(block: child)
            }
        }
    }

    open func visitUnorderedList(tight: Bool, items: [ListItem]) {
        for item in items {
            for child in item.children {
                walk(block: child)
            }
        }
    }

    open func visitTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow]) {
        for cell in head.cells {
            for node in cell.content {
                walk(inline: node)
            }
        }
        for row in body {
            for cell in row.cells {
                for node in cell.content {
                    walk(inline: node)
                }
            }
        }
    }

    open func visitThematicBreak() {}

    open func visitHTMLBlock(content: String) {}

    open func visitCustomBlock(name: String, content: String) {}

    open func visitLatexBlock(content: String) {}

    open func visitBlockDirective(name: String, arguments: String?, children: [BlockNode]) {
        for child in children {
            walk(block: child)
        }
    }

    open func visitText(_ text: String) {}

    open func visitEmphasis(children: [InlineNode]) {
        for child in children {
            walk(inline: child)
        }
    }

    open func visitStrong(children: [InlineNode]) {
        for child in children {
            walk(inline: child)
        }
    }

    open func visitStrikethrough(children: [InlineNode]) {
        for child in children {
            walk(inline: child)
        }
    }

    open func visitInlineCode(_ code: String) {}

    open func visitLink(destination: String, title: String?, children: [InlineNode]) {
        for child in children {
            walk(inline: child)
        }
    }

    open func visitImage(source: String, title: String?, children: [InlineNode]) {
        for child in children {
            walk(inline: child)
        }
    }

    open func visitSoftBreak() {}
    open func visitHardBreak() {}
    open func visitLineBreak() {}
    open func visitInlineHTML(_ html: String) {}
    open func visitLatex(content: String) {}
    open func visitCitation(index: Int, url: String?, title: String?) {}
    open func visitCustomInline(name: String, content: String) {}

    // MARK: - Walk methods

    public func walk(document: Document) {
        for block in document.blocks {
            walk(block: block)
        }
    }

    public func walk(block: BlockNode) {
        switch block {
        case .document(let children):
            visitDocument(children)
        case .heading(let level, let content):
            visitHeading(level: level, content: content)
        case .paragraph(let content):
            visitParagraph(content: content)
        case .codeBlock(let language, let content):
            visitCodeBlock(language: language, content: content)
        case .blockQuote(let children):
            visitBlockQuote(children: children)
        case .orderedList(let startIndex, let tight, let items):
            visitOrderedList(startIndex: startIndex, tight: tight, items: items)
        case .unorderedList(let tight, let items):
            visitUnorderedList(tight: tight, items: items)
        case .table(let alignments, let head, let body):
            visitTable(columnAlignments: alignments, head: head, body: body)
        case .thematicBreak:
            visitThematicBreak()
        case .htmlBlock(let content):
            visitHTMLBlock(content: content)
        case .customBlock(let name, let content):
            visitCustomBlock(name: name, content: content)
        case .latexBlock(let content):
            visitLatexBlock(content: content)
        case .blockDirective(let name, let arguments, let children):
            visitBlockDirective(name: name, arguments: arguments, children: children)
        }
    }

    public func walk(inline: InlineNode) {
        switch inline {
        case .text(let text):
            visitText(text)
        case .emphasis(let children):
            visitEmphasis(children: children)
        case .strong(let children):
            visitStrong(children: children)
        case .strikethrough(let children):
            visitStrikethrough(children: children)
        case .inlineCode(let code):
            visitInlineCode(code)
        case .link(let destination, let title, let children):
            visitLink(destination: destination, title: title, children: children)
        case .image(let source, let title, let children):
            visitImage(source: source, title: title, children: children)
        case .softBreak:
            visitSoftBreak()
        case .hardBreak:
            visitHardBreak()
        case .lineBreak:
            visitLineBreak()
        case .inlineHTML(let html):
            visitInlineHTML(html)
        case .latex(let content):
            visitLatex(content: content)
        case .citation(let index, let url, let title):
            visitCitation(index: index, url: url, title: title)
        case .customInline(let name, let content):
            visitCustomInline(name: name, content: content)
        }
    }
}
