import SwiftUI
import Hairball

// MARK: - MarkdownContent Protocol

public protocol MarkdownContentProtocol {
    var blocks: [BlockNode] { get }
}

// MARK: - Concrete content types for DSL

public struct MarkdownContent: MarkdownContentProtocol {
    public let blocks: [BlockNode]

    public init(blocks: [BlockNode]) {
        self.blocks = blocks
    }
}

// MARK: - DSL Block Types

public struct Heading: MarkdownContentProtocol {
    public let blocks: [BlockNode]

    public init(level: Int, @InlineContentBuilder _ content: () -> [InlineNode]) {
        self.blocks = [.heading(level: level, content: content())]
    }

    public init(level: Int, _ text: String) {
        self.blocks = [.heading(level: level, content: [.text(text)])]
    }
}

public struct Paragraph: MarkdownContentProtocol {
    public let blocks: [BlockNode]

    public init(@InlineContentBuilder _ content: () -> [InlineNode]) {
        self.blocks = [.paragraph(content: content())]
    }

    public init(_ text: String) {
        self.blocks = [.paragraph(content: [.text(text)])]
    }
}

public struct CodeBlock: MarkdownContentProtocol {
    public let blocks: [BlockNode]

    public init(language: String? = nil, _ code: String) {
        self.blocks = [.codeBlock(language: language, content: code)]
    }

    public init(language: String? = nil, @StringBuilder _ content: () -> String) {
        self.blocks = [.codeBlock(language: language, content: content())]
    }
}

public struct Blockquote: MarkdownContentProtocol {
    public let blocks: [BlockNode]

    public init(@MarkdownContentBuilder _ content: () -> [BlockNode]) {
        self.blocks = [.blockQuote(children: content())]
    }
}

// MARK: - String Builder

@resultBuilder
public struct StringBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }
}

// MARK: - Inline Content Builder

@resultBuilder
public struct InlineContentBuilder {
    public static func buildBlock(_ components: InlineNode...) -> [InlineNode] {
        components
    }

    public static func buildBlock(_ components: [InlineNode]...) -> [InlineNode] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: String) -> [InlineNode] {
        [.text(expression)]
    }

    public static func buildExpression(_ expression: InlineNode) -> [InlineNode] {
        [expression]
    }

    public static func buildOptional(_ component: [InlineNode]?) -> [InlineNode] {
        component ?? []
    }

    public static func buildEither(first component: [InlineNode]) -> [InlineNode] {
        component
    }

    public static func buildEither(second component: [InlineNode]) -> [InlineNode] {
        component
    }
}

// MARK: - Markdown Content Builder

@resultBuilder
public struct MarkdownContentBuilder {
    public static func buildBlock(_ components: [BlockNode]...) -> [BlockNode] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: some MarkdownContentProtocol) -> [BlockNode] {
        expression.blocks
    }

    public static func buildExpression(_ expression: BlockNode) -> [BlockNode] {
        [expression]
    }

    public static func buildOptional(_ component: [BlockNode]?) -> [BlockNode] {
        component ?? []
    }

    public static func buildEither(first component: [BlockNode]) -> [BlockNode] {
        component
    }

    public static func buildEither(second component: [BlockNode]) -> [BlockNode] {
        component
    }

    public static func buildArray(_ components: [[BlockNode]]) -> [BlockNode] {
        components.flatMap { $0 }
    }

    // Allow raw strings as paragraphs
    public static func buildExpression(_ expression: String) -> [BlockNode] {
        [.paragraph(content: [.text(expression)])]
    }
}
