import SwiftUI
import Hairball
import HairballUI

struct CustomRenderingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SwiftUI.Text("Custom Component Provider")
                    .font(.headline)
                    .padding(.horizontal)

                SwiftUI.Text("Headings use gradients, code blocks have a terminal look.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                MarkdownView(Self.sample, processors: [LatexTransformer()])
                    .markdownComponentProvider(FancyProvider())
                    .padding()

                Divider()

                SwiftUI.Text("Custom Code Block Renderer")
                    .font(.headline)
                    .padding(.horizontal)

                MarkdownView(Self.codeSample)
                    .codeBlockRenderer(NeonRenderer())
                    .padding()
            }
        }
        .navigationTitle("Custom Rendering")
    }

    static let sample = """
    # Custom Heading Style

    Headings use gradient backgrounds. Paragraphs render normally.

    ## Another Heading

    ```swift
    func greet(_ name: String) -> String {
        "Hello, \\(name)!"
    }
    ```

    > Blockquotes still use defaults.
    """

    static let codeSample = """
    ## Neon Code Blocks

    ```python
    def hello():
        print("Neon-styled!")
        return 42
    ```

    ```javascript
    const data = await fetch('/api')
    console.log(data.json())
    ```
    """
}

// MARK: - Fancy Component Provider

struct FancyProvider: MarkdownViewComponentProvider {
    func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: level <= 2 ? 28 : 20)

            InlineTextRenderer(theme: configuration.theme).render(content)
                .font(.system(size: CGFloat(28 - level * 3), weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
        }
        .padding(.top, CGFloat(24 - level * 2))
    }

    func makeParagraph(content: [InlineNode], configuration: BlockConfiguration) -> some View {
        ParagraphView(content: content)
    }

    func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    SwiftUI.Text(language.uppercased())
                }
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                SwiftUI.Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.6, green: 1.0, blue: 0.6))
                    .padding(12)
            }
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3)))
    }

    func makeBlockQuote(children: [BlockNode], configuration: BlockConfiguration) -> some View {
        BlockquoteView(children: children)
    }
    func makeOrderedList(startIndex: Int, tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        OrderedListView(startIndex: startIndex, tight: tight, items: items)
    }
    func makeUnorderedList(tight: Bool, items: [ListItem], configuration: BlockConfiguration) -> some View {
        UnorderedListView(tight: tight, items: items)
    }
    func makeTable(columnAlignments: [MarkdownTableColumnAlignment], head: MarkdownTableRow, body: [MarkdownTableRow], configuration: BlockConfiguration) -> some View {
        MarkdownTableView(columnAlignments: columnAlignments, head: head, body: body)
    }
    func makeThematicBreak(configuration: BlockConfiguration) -> some View {
        ThematicBreakView()
    }
    func makeHTMLBlock(content: String, configuration: BlockConfiguration) -> some View {
        HTMLBlockView(content: content)
    }
}

// MARK: - Neon Renderer

struct NeonRenderer: CodeBlockRenderer {
    func makeBody(configuration: CodeBlockConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Circle().fill(.yellow).frame(width: 10, height: 10)
                    Circle().fill(.green).frame(width: 10, height: 10)
                }
                Spacer()
                if configuration.hasLanguage {
                    SwiftUI.Text(configuration.languageDisplayName)
                        .font(.caption2.bold())
                        .foregroundColor(Color(red: 0, green: 1, blue: 0.8))
                }
                Spacer()
                SwiftUI.Text("\(configuration.lineCount) lines")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))

            Rectangle().fill(Color(red: 0, green: 1, blue: 0.8).opacity(0.3)).frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                SwiftUI.Text(configuration.highlightedCode)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.95))
                    .padding(14)
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0, green: 1, blue: 0.8).opacity(0.5), Color(red: 0.5, green: 0, blue: 1).opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1
                )
        )
    }
}
