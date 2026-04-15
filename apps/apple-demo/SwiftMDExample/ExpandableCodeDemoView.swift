import SwiftUI
import Hairball
import HairballUI

struct ExpandableCodeDemoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SwiftUI.Text("Expandable Code Blocks")
                    .font(.headline)
                    .padding(.horizontal)

                Group {
                    SwiftUI.Text("Collapsed by default:").font(.subheadline.bold())

                    ExpandableCodeBlockView(
                        language: "swift",
                        content: Self.longSwift,
                        collapsedHeight: 120,
                        animationDuration: 0.35
                    )
                }
                .padding(.horizontal)

                Divider()

                Group {
                    SwiftUI.Text("Selectable Code View").font(.headline)

                    SelectableCodeView(
                        code: Self.jsonCode,
                        language: "json"
                    )
                }
                .padding(.horizontal)

                Divider()

                Group {
                    SwiftUI.Text("Plain Text Preview (5 lines max)").font(.headline)
                    PlainTextPreviewView(Self.plainText, maxLines: 5)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Code Blocks")
    }

    static let longSwift = """
    import Foundation

    struct MarkdownParser {
        let options: ParseOptions

        init(options: ParseOptions = .default) {
            self.options = options
        }

        func parse(_ input: String) -> Document {
            let converter = MarkdownASTConverter()
            let rawDocument = Markdown.Document(parsing: input)
            let blocks = rawDocument.children.compactMap {
                converter.convertBlock($0)
            }
            return Document(blocks: blocks)
        }
    }

    struct ParseOptions: OptionSet {
        let rawValue: Int
        static let gfmTables = ParseOptions(rawValue: 1 << 0)
        static let strikethrough = ParseOptions(rawValue: 1 << 1)
        static let taskLists = ParseOptions(rawValue: 1 << 2)
        static let `default`: ParseOptions = [.gfmTables, .strikethrough, .taskLists]
    }
    """

    static let jsonCode = """
    {
        "library": "Hairball",
        "version": "1.0.0",
        "targets": {
            "Hairball": { "files": 15, "features": ["parsing", "AST", "streaming"] },
            "HairballUI": { "files": 30, "features": ["rendering", "theming", "animation"] }
        }
    }
    """

    static let plainText = """
    This is plain text with no highlighting.
    Line 2: just monospaced text.
    Line 3: useful for logs or raw output.
    Line 4: supports line limiting.
    Line 5: this is the last visible line.
    Line 6: you won't see this.
    Line 7: or this.
    """
}
