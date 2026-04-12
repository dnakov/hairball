import SwiftUI
import Hairball

// MARK: - Block Configuration

public struct BlockConfiguration {
    public let block: BlockNode
    public let theme: MarkdownTheme
    public let nestingLevel: Int

    public init(block: BlockNode, theme: MarkdownTheme, nestingLevel: Int = 0) {
        self.block = block
        self.theme = theme
        self.nestingLevel = nestingLevel
    }
}

// MARK: - MarkdownViewComponentProvider Protocol

public protocol MarkdownViewComponentProvider {
    associatedtype HeadingBody: View
    associatedtype ParagraphBody: View
    associatedtype CodeBlockBody: View
    associatedtype BlockQuoteBody: View
    associatedtype OrderedListBody: View
    associatedtype UnorderedListBody: View
    associatedtype TableBody: View
    associatedtype ThematicBreakBody: View
    associatedtype HTMLBlockBody: View

    @ViewBuilder func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> HeadingBody
    @ViewBuilder func makeParagraph(content: [InlineNode], configuration: BlockConfiguration) -> ParagraphBody
    @ViewBuilder func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> CodeBlockBody
    @ViewBuilder func makeBlockQuote(children: [BlockNode], configuration: BlockConfiguration) -> BlockQuoteBody
    @ViewBuilder func makeOrderedList(startIndex: Int, tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> OrderedListBody
    @ViewBuilder func makeUnorderedList(tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> UnorderedListBody
    @ViewBuilder func makeTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow], configuration: BlockConfiguration) -> TableBody
    @ViewBuilder func makeThematicBreak(configuration: BlockConfiguration) -> ThematicBreakBody
    @ViewBuilder func makeHTMLBlock(content: String, configuration: BlockConfiguration) -> HTMLBlockBody
}

// MARK: - DefaultMarkdownViewComponentProvider

public struct DefaultMarkdownViewComponentProvider: MarkdownViewComponentProvider {
    public init() {}

    public func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeParagraph(content: [InlineNode], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeBlockQuote(children: [BlockNode], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeOrderedList(startIndex: Int, tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeUnorderedList(tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow], configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeThematicBreak(configuration: BlockConfiguration) -> some View {
        EmptyView()
    }

    public func makeHTMLBlock(content: String, configuration: BlockConfiguration) -> some View {
        EmptyView()
    }
}

// MARK: - Type-erased wrapper

public struct AnyMarkdownViewComponentProvider: MarkdownViewComponentProvider, @unchecked Sendable {
    private let _makeHeading: (Int, [InlineNode], BlockConfiguration) -> AnyView
    private let _makeParagraph: ([InlineNode], BlockConfiguration) -> AnyView
    private let _makeCodeBlock: (String?, String, BlockConfiguration) -> AnyView
    private let _makeBlockQuote: ([BlockNode], BlockConfiguration) -> AnyView
    private let _makeOrderedList: (Int, Bool, [ListItem], BlockConfiguration) -> AnyView
    private let _makeUnorderedList: (Bool, [ListItem], BlockConfiguration) -> AnyView
    private let _makeTable: ([MarkdownTableColumnAlignment], MarkdownTableRow, [MarkdownTableRow], BlockConfiguration) -> AnyView
    private let _makeThematicBreak: (BlockConfiguration) -> AnyView
    private let _makeHTMLBlock: (String, BlockConfiguration) -> AnyView

    public init<P: MarkdownViewComponentProvider>(_ provider: P) {
        _makeHeading = { AnyView(provider.makeHeading(level: $0, content: $1, configuration: $2)) }
        _makeParagraph = { AnyView(provider.makeParagraph(content: $0, configuration: $1)) }
        _makeCodeBlock = { AnyView(provider.makeCodeBlock(language: $0, code: $1, configuration: $2)) }
        _makeBlockQuote = { AnyView(provider.makeBlockQuote(children: $0, configuration: $1)) }
        _makeOrderedList = { AnyView(provider.makeOrderedList(startIndex: $0, tight: $1, items: $2, configuration: $3)) }
        _makeUnorderedList = { AnyView(provider.makeUnorderedList(tight: $0, items: $1, configuration: $2)) }
        _makeTable = { (alignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow], config: BlockConfiguration) in AnyView(provider.makeTable(columnAlignments: alignments, head: head, body: body, configuration: config)) }
        _makeThematicBreak = { AnyView(provider.makeThematicBreak(configuration: $0)) }
        _makeHTMLBlock = { AnyView(provider.makeHTMLBlock(content: $0, configuration: $1)) }
    }

    public func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        _makeHeading(level, content, configuration)
    }

    public func makeParagraph(content: [InlineNode], configuration: BlockConfiguration) -> some View {
        _makeParagraph(content, configuration)
    }

    public func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        _makeCodeBlock(language, code, configuration)
    }

    public func makeBlockQuote(children: [BlockNode], configuration: BlockConfiguration) -> some View {
        _makeBlockQuote(children, configuration)
    }

    public func makeOrderedList(startIndex: Int, tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        _makeOrderedList(startIndex, tight, items, configuration)
    }

    public func makeUnorderedList(tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        _makeUnorderedList(tight, items, configuration)
    }

    public func makeTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow], configuration: BlockConfiguration) -> some View {
        _makeTable(columnAlignments, head, body, configuration)
    }

    public func makeThematicBreak(configuration: BlockConfiguration) -> some View {
        _makeThematicBreak(configuration)
    }

    public func makeHTMLBlock(content: String, configuration: BlockConfiguration) -> some View {
        _makeHTMLBlock(content, configuration)
    }
}

// MARK: - Environment Key

private struct MarkdownViewComponentProviderKey: EnvironmentKey {
    static let defaultValue: AnyMarkdownViewComponentProvider = AnyMarkdownViewComponentProvider(DefaultMarkdownViewComponentProvider())
}

extension EnvironmentValues {
    public var markdownComponentProvider: AnyMarkdownViewComponentProvider {
        get { self[MarkdownViewComponentProviderKey.self] }
        set { self[MarkdownViewComponentProviderKey.self] = newValue }
    }
}

extension View {
    public func markdownComponentProvider(_ provider: some MarkdownViewComponentProvider) -> some View {
        environment(\.markdownComponentProvider, AnyMarkdownViewComponentProvider(provider))
    }
}
