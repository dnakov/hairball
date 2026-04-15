import Foundation
import Markdown

public struct ParseOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let parseBlockDirectives = ParseOptions(rawValue: 1 << 0)
    public static let parseSymbolLinks = ParseOptions(rawValue: 1 << 1)
    public static let parseMinimalDoxygen = ParseOptions(rawValue: 1 << 2)

    public static let `default`: ParseOptions = [.parseBlockDirectives]
}

public struct MarkdownParser: Sendable {
    public var options: ParseOptions

    public init(options: ParseOptions = .default) {
        self.options = options
    }

    public func parse(_ markdown: String) -> Document {
        var markdownOptions: Markdown.ParseOptions = []

        if options.contains(.parseBlockDirectives) {
            markdownOptions.insert(.parseBlockDirectives)
        }

        if options.contains(.parseSymbolLinks) {
            markdownOptions.insert(.parseSymbolLinks)
        }
        if options.contains(.parseMinimalDoxygen) {
            markdownOptions.insert(.parseMinimalDoxygen)
        }

        let source = Markdown.Document(parsing: markdown, options: markdownOptions)
        let converter = MarkdownASTConverter()
        let blocks = converter.convertBlockChildren(source)
        return Document(blocks: blocks)
    }
}

// MARK: - AST Converter

private final class MarkdownASTConverter {
    func convertBlockChildren(_ node: some Markdown.Markup) -> [BlockNode] {
        Array(node.children.compactMap { self.convertBlock($0) })
    }

    func convertInlineChildren(_ node: some Markdown.Markup) -> [InlineNode] {
        Array(node.children.compactMap { self.convertInline($0) })
    }

    func convertBlock(_ markup: any Markdown.Markup) -> BlockNode? {
        if let doc = markup as? Markdown.Document {
            return .document(convertBlockChildren(doc))
        }
        if let heading = markup as? Markdown.Heading {
            return .heading(level: heading.level, content: convertInlineChildren(heading))
        }
        if let paragraph = markup as? Markdown.Paragraph {
            return .paragraph(content: convertInlineChildren(paragraph))
        }
        if let codeBlock = markup as? Markdown.CodeBlock {
            let lang = codeBlock.language?.isEmpty == true ? nil : codeBlock.language
            return .codeBlock(language: lang, content: codeBlock.code)
        }
        if let blockQuote = markup as? Markdown.BlockQuote {
            return .blockQuote(children: convertBlockChildren(blockQuote))
        }
        if let orderedList = markup as? Markdown.OrderedList {
            let items = Array(orderedList.children.compactMap { child -> ListItem? in
                guard let item = child as? Markdown.ListItem else { return nil }
                return self.convertListItem(item)
            })
            let tight = isTightList(orderedList)
            return .orderedList(startIndex: Int(orderedList.startIndex), tight: tight, items: items)
        }
        if let unorderedList = markup as? Markdown.UnorderedList {
            let items = Array(unorderedList.children.compactMap { child -> ListItem? in
                guard let item = child as? Markdown.ListItem else { return nil }
                return self.convertListItem(item)
            })
            let tight = isTightList(unorderedList)
            return .unorderedList(tight: tight, items: items)
        }
        if let table = markup as? Markdown.Table {
            let alignments = table.columnAlignments.map { self.convertAlignment($0) }
            let head = convertTableHead(table.head)
            let body = Array(table.body.rows.map { self.convertTableRow($0) })
            return .table(columnAlignments: alignments, head: head, body: body)
        }
        if markup is Markdown.ThematicBreak {
            return .thematicBreak
        }
        if let htmlBlock = markup as? Markdown.HTMLBlock {
            return .htmlBlock(content: htmlBlock.rawHTML)
        }
        if let directive = markup as? Markdown.BlockDirective {
            let args = directive.argumentText.segments.map(\.trimmedText).joined()
            return .blockDirective(
                name: directive.name,
                arguments: args.isEmpty ? nil : args,
                children: convertBlockChildren(directive)
            )
        }
        // List items are handled via convertListItem in list processing
        if markup is Markdown.ListItem {
            return nil
        }
        return nil
    }

    func convertInline(_ markup: any Markdown.Markup) -> InlineNode? {
        if let text = markup as? Markdown.Text {
            return .text(text.string)
        }
        if let emphasis = markup as? Markdown.Emphasis {
            return .emphasis(children: convertInlineChildren(emphasis))
        }
        if let strong = markup as? Markdown.Strong {
            return .strong(children: convertInlineChildren(strong))
        }
        if let strikethrough = markup as? Markdown.Strikethrough {
            return .strikethrough(children: convertInlineChildren(strikethrough))
        }
        if let inlineCode = markup as? Markdown.InlineCode {
            return .inlineCode(inlineCode.code)
        }
        if let link = markup as? Markdown.Link {
            return .link(
                destination: link.destination ?? "",
                title: link.title,
                children: convertInlineChildren(link)
            )
        }
        if let image = markup as? Markdown.Image {
            return .image(
                source: image.source ?? "",
                title: image.title,
                children: convertInlineChildren(image)
            )
        }
        if markup is Markdown.SoftBreak {
            return .softBreak
        }
        if markup is Markdown.LineBreak {
            return .hardBreak
        }
        if let inlineHTML = markup as? Markdown.InlineHTML {
            return .inlineHTML(inlineHTML.rawHTML)
        }
        if let symbolLink = markup as? Markdown.SymbolLink {
            return .inlineCode(symbolLink.destination ?? "")
        }
        return nil
    }

    // MARK: - Helpers

    private func convertListItem(_ item: Markdown.ListItem) -> ListItem {
        let checkbox: CheckboxState?
        if let cb = item.checkbox {
            checkbox = cb == .checked ? .checked : .unchecked
        } else {
            checkbox = nil
        }
        return ListItem(children: convertBlockChildren(item), checkbox: checkbox)
    }

    private func convertAlignment(_ alignment: Markdown.Table.ColumnAlignment?) -> MarkdownTableColumnAlignment {
        guard let alignment = alignment else { return .none }
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    private func convertTableHead(_ head: Markdown.Table.Head) -> MarkdownTableRow {
        let cells = Array(head.cells.map { cell in
            MarkdownTableCell(content: self.convertInlineChildren(cell))
        })
        return MarkdownTableRow(cells: cells)
    }

    private func convertTableRow(_ row: Markdown.Table.Row) -> MarkdownTableRow {
        let cells = Array(row.cells.map { cell in
            MarkdownTableCell(content: self.convertInlineChildren(cell))
        })
        return MarkdownTableRow(cells: cells)
    }

    private func isTightList(_ list: some Markdown.ListItemContainer) -> Bool {
        for item in list.children {
            guard let listItem = item as? Markdown.ListItem else { continue }
            if listItem.childCount > 1 {
                return false
            }
        }
        return true
    }
}
