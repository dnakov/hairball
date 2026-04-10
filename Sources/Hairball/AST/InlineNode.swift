import Foundation

public indirect enum InlineNode: Equatable, Hashable, Sendable {
    case text(String)
    case emphasis(children: [InlineNode])
    case strong(children: [InlineNode])
    case strikethrough(children: [InlineNode])
    case inlineCode(String)
    case link(destination: String, title: String?, children: [InlineNode])
    case image(source: String, title: String?, children: [InlineNode])
    case softBreak
    case hardBreak
    case lineBreak
    case inlineHTML(String)
    case latex(content: String)
    case citation(index: Int, url: String?, title: String?)
    case customInline(name: String, content: String)
}
