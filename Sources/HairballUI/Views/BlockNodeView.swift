import SwiftUI
import Hairball

/// Dispatches a single `BlockNode` to the appropriate rendering view.
public struct BlockNodeView: View {
    @Environment(\.markdownTheme) private var theme

    private let node: BlockNode

    public init(node: BlockNode) {
        self.node = node
    }

    public var body: some View {
        switch node {
        case .document(let children):
            VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    BlockNodeView(node: child)
                }
            }

        case .heading(let level, let content):
            // `.equatable()` lets SwiftUI short-circuit body re-eval when
            // heading inputs are stable — cheap `Array<InlineNode>`
            // comparison vs. the much more expensive re-run of
            // `InlineTextRenderer` and styled-text layout.
            HeadingView(level: level, content: content).equatable()

        case .paragraph(let content):
            // Same reason as `.heading` above. `StyledTextLayoutComputer`
            // was the single largest cost inside this view list in
            // profiling; this Equatable short-circuit is the biggest
            // render-side win of the parse-cache / Equatable refactor.
            ParagraphView(content: content).equatable()

        case .codeBlock(let language, let content):
            CodeBlockView(language: language, content: content)

        case .blockQuote(let children):
            BlockquoteView(children: children)

        case .orderedList(let startIndex, let tight, let items):
            OrderedListView(startIndex: startIndex, tight: tight, items: items)

        case .unorderedList(let tight, let items):
            UnorderedListView(tight: tight, items: items)

        case .table(let alignments, let head, let body):
            MarkdownTableView(columnAlignments: alignments, head: head, body: body)

        case .thematicBreak:
            ThematicBreakView()

        case .htmlBlock(let content):
            HTMLBlockView(content: content)

        case .customBlock(_, let content):
            Text(content)
                .font(theme.codeBlock.font)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

        case .latexBlock(let content):
            LatexBlockView(content: content)

        case .blockDirective(let name, let arguments, let children):
            BlockDirectiveView(name: name, arguments: arguments, children: children)
        }
    }
}
