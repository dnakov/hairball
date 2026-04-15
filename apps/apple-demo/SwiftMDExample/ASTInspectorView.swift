import SwiftUI
import Hairball
import HairballUI

struct ASTInspectorView: View {
    @State private var markdown = "# Hello\n\nThis is **bold** and *italic* with `code`.\n\n- Item one\n- Item two\n\n```swift\nlet x = 42\n```"
    @State private var document = Document(blocks: [])

    private let parser = MarkdownParser()

    var body: some View {
        VStack(spacing: 0) {
            // Editor
            VStack(alignment: .leading, spacing: 4) {
                SwiftUI.Text("Markdown Input").font(.headline)
                TextEditor(text: $markdown)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 200)
                    .border(Color.secondary.opacity(0.3))
                    .onChange(of: markdown) { newValue in
                        document = parser.parse(newValue)
                    }
            }
            .padding()

            Divider()

            // AST + Preview
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SwiftUI.Text("AST (\(document.blocks.count) blocks)").font(.headline)

                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                            ASTNodeView(block: block, depth: 0)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))

                    Divider()

                    SwiftUI.Text("Rendered").font(.headline)
                    MarkdownView(document: document)
                }
                .padding()
            }
        }
        .onAppear { document = parser.parse(markdown) }
        .navigationTitle("AST Inspector")
    }
}

struct ASTNodeView: View {
    let block: BlockNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                SwiftUI.Text(String(repeating: "  ", count: depth))
                Image(systemName: icon).foregroundColor(color).frame(width: 14)
                SwiftUI.Text(label).foregroundColor(color)
            }
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                ASTNodeView(block: child, depth: depth + 1)
            }
            if !inlines.isEmpty {
                HStack(spacing: 4) {
                    SwiftUI.Text(String(repeating: "  ", count: depth + 1))
                    SwiftUI.Text(inlineSummary).foregroundColor(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var label: String {
        switch block {
        case .document(let c): return "document [\(c.count)]"
        case .heading(let l, _): return "heading h\(l)"
        case .paragraph: return "paragraph"
        case .codeBlock(let lang, let code): return "codeBlock\(lang.map { " \($0)" } ?? "") [\(code.count) chars]"
        case .blockQuote(let c): return "blockQuote [\(c.count)]"
        case .orderedList(let s, _, let items): return "orderedList start=\(s) [\(items.count)]"
        case .unorderedList(_, let items): return "unorderedList [\(items.count)]"
        case .table(let a, _, let b): return "table [\(a.count) cols, \(b.count + 1) rows]"
        case .thematicBreak: return "thematicBreak"
        case .htmlBlock: return "htmlBlock"
        case .latexBlock: return "latexBlock"
        case .customBlock(let n, _): return "customBlock(\(n))"
        case .blockDirective(let n, _, _): return "blockDirective(\(n))"
        }
    }

    private var icon: String {
        switch block {
        case .heading: return "textformat.size"
        case .paragraph: return "text.alignleft"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        case .blockQuote: return "text.quote"
        case .orderedList: return "list.number"
        case .unorderedList: return "list.bullet"
        case .table: return "tablecells"
        case .thematicBreak: return "minus"
        case .latexBlock: return "function"
        default: return "doc.text"
        }
    }

    private var color: Color {
        switch block {
        case .heading: return .blue
        case .codeBlock: return .green
        case .blockQuote: return .orange
        case .orderedList, .unorderedList: return .purple
        case .table: return .teal
        case .latexBlock: return .pink
        default: return .primary
        }
    }

    private var children: [BlockNode] {
        switch block {
        case .document(let c), .blockQuote(let c), .blockDirective(_, _, let c): return c
        case .orderedList(_, _, let items): return items.flatMap(\.children)
        case .unorderedList(_, let items): return items.flatMap(\.children)
        default: return []
        }
    }

    private var inlines: [InlineNode] {
        switch block {
        case .heading(_, let c), .paragraph(let c): return c
        default: return []
        }
    }

    private var inlineSummary: String {
        let s = inlines.map(describe).joined()
        return s.count > 60 ? String(s.prefix(57)) + "..." : s
    }

    private func describe(_ n: InlineNode) -> String {
        switch n {
        case .text(let s): return s
        case .emphasis(let c): return "*\(c.map(describe).joined())*"
        case .strong(let c): return "**\(c.map(describe).joined())**"
        case .inlineCode(let s): return "`\(s)`"
        case .softBreak: return " "
        case .hardBreak, .lineBreak: return "\\n"
        default: return "[\(n)]"
        }
    }
}
