import Foundation
import Hairball

private struct DocumentFixture: Encodable {
    let blocks: [BlockFixture]
    let metadata: [String: String]
    let plainText: String
}

private indirect enum BlockFixture: Encodable {
    case document(children: [BlockFixture])
    case heading(level: Int, content: [InlineFixture])
    case paragraph(content: [InlineFixture])
    case codeBlock(language: String?, content: String)
    case blockQuote(children: [BlockFixture])
    case orderedList(startIndex: Int, tight: Bool, items: [ListItemFixture])
    case unorderedList(tight: Bool, items: [ListItemFixture])
    case table(columnAlignments: [String], head: TableRowFixture, body: [TableRowFixture])
    case thematicBreak
    case htmlBlock(content: String)
    case customBlock(name: String, content: String)
    case latexBlock(content: String)
    case blockDirective(name: String, arguments: String?, children: [BlockFixture])

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .document(let children):
            try container.encode("document", forKey: .type)
            try container.encode(children, forKey: .children)
        case .heading(let level, let content):
            try container.encode("heading", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(content, forKey: .content)
        case .paragraph(let content):
            try container.encode("paragraph", forKey: .type)
            try container.encode(content, forKey: .content)
        case .codeBlock(let language, let content):
            try container.encode("codeBlock", forKey: .type)
            try container.encodeIfPresent(language, forKey: .language)
            try container.encode(content, forKey: .content)
        case .blockQuote(let children):
            try container.encode("blockQuote", forKey: .type)
            try container.encode(children, forKey: .children)
        case .orderedList(let startIndex, let tight, let items):
            try container.encode("orderedList", forKey: .type)
            try container.encode(startIndex, forKey: .startIndex)
            try container.encode(tight, forKey: .tight)
            try container.encode(items, forKey: .items)
        case .unorderedList(let tight, let items):
            try container.encode("unorderedList", forKey: .type)
            try container.encode(tight, forKey: .tight)
            try container.encode(items, forKey: .items)
        case .table(let columnAlignments, let head, let body):
            try container.encode("table", forKey: .type)
            try container.encode(columnAlignments, forKey: .columnAlignments)
            try container.encode(head, forKey: .head)
            try container.encode(body, forKey: .body)
        case .thematicBreak:
            try container.encode("thematicBreak", forKey: .type)
        case .htmlBlock(let content):
            try container.encode("htmlBlock", forKey: .type)
            try container.encode(content, forKey: .content)
        case .customBlock(let name, let content):
            try container.encode("customBlock", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(content, forKey: .content)
        case .latexBlock(let content):
            try container.encode("latexBlock", forKey: .type)
            try container.encode(content, forKey: .content)
        case .blockDirective(let name, let arguments, let children):
            try container.encode("blockDirective", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(arguments, forKey: .arguments)
            try container.encode(children, forKey: .children)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case level
        case content
        case language
        case children
        case startIndex
        case tight
        case items
        case columnAlignments
        case head
        case body
        case name
        case arguments
    }
}

private struct ListItemFixture: Encodable {
    let checkbox: String?
    let children: [BlockFixture]
}

private struct TableRowFixture: Encodable {
    let cells: [TableCellFixture]
}

private struct TableCellFixture: Encodable {
    let content: [InlineFixture]
}

private indirect enum InlineFixture: Encodable {
    case text(String)
    case emphasis(children: [InlineFixture])
    case strong(children: [InlineFixture])
    case strikethrough(children: [InlineFixture])
    case inlineCode(String)
    case link(destination: String, title: String?, children: [InlineFixture])
    case image(source: String, title: String?, children: [InlineFixture])
    case softBreak
    case hardBreak
    case lineBreak
    case inlineHTML(String)
    case latex(String)
    case citation(index: Int, url: String?, title: String?)
    case customInline(name: String, content: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .value)
        case .emphasis(let children):
            try container.encode("emphasis", forKey: .type)
            try container.encode(children, forKey: .children)
        case .strong(let children):
            try container.encode("strong", forKey: .type)
            try container.encode(children, forKey: .children)
        case .strikethrough(let children):
            try container.encode("strikethrough", forKey: .type)
            try container.encode(children, forKey: .children)
        case .inlineCode(let value):
            try container.encode("inlineCode", forKey: .type)
            try container.encode(value, forKey: .value)
        case .link(let destination, let title, let children):
            try container.encode("link", forKey: .type)
            try container.encode(destination, forKey: .destination)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(children, forKey: .children)
        case .image(let source, let title, let children):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(children, forKey: .children)
        case .softBreak:
            try container.encode("softBreak", forKey: .type)
        case .hardBreak:
            try container.encode("hardBreak", forKey: .type)
        case .lineBreak:
            try container.encode("lineBreak", forKey: .type)
        case .inlineHTML(let value):
            try container.encode("inlineHTML", forKey: .type)
            try container.encode(value, forKey: .value)
        case .latex(let value):
            try container.encode("latex", forKey: .type)
            try container.encode(value, forKey: .value)
        case .citation(let index, let url, let title):
            try container.encode("citation", forKey: .type)
            try container.encode(index, forKey: .index)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(title, forKey: .title)
        case .customInline(let name, let content):
            try container.encode("customInline", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(content, forKey: .content)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case children
        case destination
        case title
        case source
        case index
        case url
        case name
        case content
    }
}

private struct IdentifiedBlockFixture: Encodable {
    let id: String
    let type: String
    let plainText: String
}

private struct StreamingStageFixture: Encodable {
    let stage: Int
    let input: String
    let rawBlockTypes: [String]
    let stabilizedBlockTypes: [String]
}

private let parserFixtureMarkdown = """
# Fixtures

Paragraph with **bold**, `code`, [link](https://example.com), and task list:

- [x] complete
- [ ] pending

| A | B |
|---|---|
| 1 | 2 |
"""

private let processorFixtureMarkdown = """
Visit https://example.com and cite [1](https://example.com "Example").

Inline math $E = mc^2$ and footnote[^2].
"""

private let identifiedBlocksMarkdown = """
# Intro

Paragraph one.

Paragraph two with `inline code`.
"""

private let directiveFixtureMarkdown = """
@Tutorial {
Body
}
"""

@main
struct HairballFixtureExporter {
    static func main() throws {
        let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("spec/fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try writeFixture(named: "parser.json", value: makeParserFixture(), outputDir: outputDir)
        try writeFixture(named: "processor.json", value: makeProcessorFixture(), outputDir: outputDir)
        try writeFixture(named: "metadata.json", value: makeMetadataFixture(), outputDir: outputDir)
        try writeFixture(named: "identified_blocks.json", value: makeIdentifiedBlocksFixture(), outputDir: outputDir)
        try writeFixture(named: "streaming.json", value: makeStreamingFixture(), outputDir: outputDir)
        try writeFixture(named: "parse_options.json", value: makeParseOptionsFixture(), outputDir: outputDir)
    }

    private static func writeFixture<T: Encodable>(named name: String, value: T, outputDir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        try data.write(to: outputDir.appendingPathComponent(name))
    }

    private static func makeParserFixture() -> [String: DocumentFixture] {
        let parser = MarkdownParser()
        let document = parser.parse(parserFixtureMarkdown)
        return ["document": fixture(document)]
    }

    private static func makeProcessorFixture() -> [String: DocumentFixture] {
        let parser = MarkdownParser()
        let processors: [any MarkdownProcessor] = [
            AutoLinkTransformer(),
            CitationProcessor(),
            LatexTransformer(),
        ]
        var document = parser.parse(processorFixtureMarkdown)
        for processor in processors {
            document = processor.process(document)
        }
        return ["document": fixture(document)]
    }

    private static func makeMetadataFixture() -> [String: [String: String]] {
        let parser = MarkdownParser()
        var document = parser.parse(processorFixtureMarkdown)
        document = CitationProcessor().process(document)
        return ["metadata": document.metadata]
    }

    private static func makeIdentifiedBlocksFixture() -> [String: [IdentifiedBlockFixture]] {
        let parser = MarkdownParser()
        let document = parser.parse(identifiedBlocksMarkdown)
        return [
            "identifiedBlocks": IdentifiedBlock.identify(document.blocks).map { item in
                IdentifiedBlockFixture(
                    id: item.id,
                    type: blockTypeName(item.block),
                    plainText: Document(blocks: [item.block]).plainText
                )
            },
        ]
    }

    private static func makeStreamingFixture() -> [String: [StreamingStageFixture]] {
        let parser = MarkdownParser()
        let codeFenceStages = [
            "Hello world\n",
            "Hello world\n```",
            "Hello world\n```swift",
            "Hello world\n```swift\n",
            "Hello world\n```swift\nlet x = 42",
            "Hello world\n```swift\nlet x = 42\n",
            "Hello world\n```swift\nlet x = 42\n```",
        ]
        let tableStages = [
            "Text\n",
            "Text\n| A | B |",
            "Text\n| A | B |\n",
            "Text\n| A | B |\n|---|---|",
            "Text\n| A | B |\n|---|---|\n| 1 | 2 |",
        ]

        return [
            "codeFence": codeFenceStages.enumerated().map { fixture(for: $0.offset, text: $0.element, parser: parser) },
            "table": tableStages.enumerated().map { fixture(for: $0.offset, text: $0.element, parser: parser) },
        ]
    }

    private static func makeParseOptionsFixture() -> [String: DocumentFixture] {
        let enabled = MarkdownParser().parse(directiveFixtureMarkdown)
        let disabled = MarkdownParser(options: []).parse(directiveFixtureMarkdown)
        return [
            "default": fixture(enabled),
            "disabled": fixture(disabled),
        ]
    }

    private static func fixture(for stage: Int, text: String, parser: MarkdownParser) -> StreamingStageFixture {
        let rawDocument = parser.parse(text)
        let stabilized = stabilizeLastBlock(rawDocument.blocks)
        return StreamingStageFixture(
            stage: stage,
            input: text,
            rawBlockTypes: rawDocument.blocks.map(blockTypeName),
            stabilizedBlockTypes: stabilized.map(blockTypeName)
        )
    }

    private static func stabilizeLastBlock(_ blocks: [BlockNode]) -> [BlockNode] {
        guard let last = blocks.last else { return blocks }

        if case .paragraph(let content) = last {
            let text = content.compactMap { node -> String? in
                if case .text(let value) = node { return value }
                return nil
            }.joined().trimmingCharacters(in: .whitespaces)

            if text.hasPrefix("|") && text.filter({ $0 == "|" }).count >= 3 {
                return Array(blocks.dropLast())
            }
        }

        return blocks
    }

    private static func fixture(_ document: Document) -> DocumentFixture {
        DocumentFixture(
            blocks: document.blocks.map(fixture),
            metadata: document.metadata,
            plainText: document.plainText
        )
    }

    private static func fixture(_ block: BlockNode) -> BlockFixture {
        switch block {
        case .document(let children):
            return .document(children: children.map(fixture))
        case .heading(let level, let content):
            return .heading(level: level, content: content.map(fixture))
        case .paragraph(let content):
            return .paragraph(content: content.map(fixture))
        case .codeBlock(let language, let content):
            return .codeBlock(language: language, content: content)
        case .blockQuote(let children):
            return .blockQuote(children: children.map(fixture))
        case .orderedList(let startIndex, let tight, let items):
            return .orderedList(startIndex: startIndex, tight: tight, items: items.map(fixture))
        case .unorderedList(let tight, let items):
            return .unorderedList(tight: tight, items: items.map(fixture))
        case .table(let columnAlignments, let head, let body):
            return .table(
                columnAlignments: columnAlignments.map(alignmentName),
                head: fixture(head),
                body: body.map(fixture)
            )
        case .thematicBreak:
            return .thematicBreak
        case .htmlBlock(let content):
            return .htmlBlock(content: content)
        case .customBlock(let name, let content):
            return .customBlock(name: name, content: content)
        case .latexBlock(let content):
            return .latexBlock(content: content)
        case .blockDirective(let name, let arguments, let children):
            return .blockDirective(name: name, arguments: arguments, children: children.map(fixture))
        }
    }

    private static func fixture(_ item: ListItem) -> ListItemFixture {
        ListItemFixture(
            checkbox: item.checkbox.map(checkboxName),
            children: item.children.map(fixture)
        )
    }

    private static func fixture(_ row: MarkdownTableRow) -> TableRowFixture {
        TableRowFixture(cells: row.cells.map(fixture))
    }

    private static func fixture(_ cell: MarkdownTableCell) -> TableCellFixture {
        TableCellFixture(content: cell.content.map(fixture))
    }

    private static func fixture(_ inline: InlineNode) -> InlineFixture {
        switch inline {
        case .text(let value):
            return .text(value)
        case .emphasis(let children):
            return .emphasis(children: children.map(fixture))
        case .strong(let children):
            return .strong(children: children.map(fixture))
        case .strikethrough(let children):
            return .strikethrough(children: children.map(fixture))
        case .inlineCode(let value):
            return .inlineCode(value)
        case .link(let destination, let title, let children):
            return .link(destination: destination, title: title, children: children.map(fixture))
        case .image(let source, let title, let children):
            return .image(source: source, title: title, children: children.map(fixture))
        case .softBreak:
            return .softBreak
        case .hardBreak:
            return .hardBreak
        case .lineBreak:
            return .lineBreak
        case .inlineHTML(let value):
            return .inlineHTML(value)
        case .latex(let value):
            return .latex(value)
        case .citation(let index, let url, let title):
            return .citation(index: index, url: url, title: title)
        case .customInline(let name, let content):
            return .customInline(name: name, content: content)
        }
    }

    private static func blockTypeName(_ block: BlockNode) -> String {
        switch block {
        case .document: return "document"
        case .heading: return "heading"
        case .paragraph: return "paragraph"
        case .codeBlock: return "codeBlock"
        case .blockQuote: return "blockQuote"
        case .orderedList: return "orderedList"
        case .unorderedList: return "unorderedList"
        case .table: return "table"
        case .thematicBreak: return "thematicBreak"
        case .htmlBlock: return "htmlBlock"
        case .customBlock: return "customBlock"
        case .latexBlock: return "latexBlock"
        case .blockDirective: return "blockDirective"
        }
    }

    private static func alignmentName(_ alignment: MarkdownTableColumnAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .none: return "none"
        }
    }

    private static func checkboxName(_ checkbox: CheckboxState) -> String {
        switch checkbox {
        case .checked: return "checked"
        case .unchecked: return "unchecked"
        }
    }
}
