import SwiftUI
import Hairball
import HairballUI

struct ThemeShowcaseView: View {
    @State private var selectedTheme = 0

    private let themes: [(String, MarkdownTheme)] = [
        ("Default", .default),
        ("Assistant", .assistantBubble),
        ("User", .userBubble),
        ("Pending", .userBubblePending),
        ("Dark", Self.darkTheme),
        ("Minimal", Self.minimalTheme),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Theme", selection: $selectedTheme) {
                ForEach(Array(themes.enumerated()), id: \.offset) { i, t in
                    Text(t.0).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                MarkdownView(Self.sample)
                    .markdownTheme(themes[selectedTheme].1)
                    .padding()
                    .animation(.easeInOut, value: selectedTheme)
            }
        }
        .navigationTitle("Themes")
    }

    static let sample = """
    # Theme Preview

    **Same content**, different themes. Switch above.

    ## Code

    ```swift
    struct Greeting {
        let name: String
        var message: String { "Hello, \\(name)!" }
    }
    ```

    ## Formatting

    - **Bold** and *italic*
    - Single-backtick inline code: `Inline code`
    - Compare plain text vs `let count = 42` vs `URLSession.shared`
    - [A link](https://example.com)

    > Blockquote styling.

    | A | B |
    |---|---|
    | 1 | 2 |
    | 3 | 4 |

    ---

    End of preview.
    """

    static let darkTheme = MarkdownTheme(
        bodyFont: .system(size: 15),
        foregroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
        paragraphSpacing: 10,
        codeBlock: CodeBlockStyle(
            backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
            textColor: Color(red: 0.85, green: 0.85, blue: 0.85),
            cornerRadius: 8
        ),
        inlineCode: InlineCodeStyle(
            backgroundColor: Color(red: 0.2, green: 0.2, blue: 0.22),
            textColor: Color(red: 0.95, green: 0.6, blue: 0.4)
        ),
        blockquote: BlockquoteStyle(
            borderColor: Color(red: 0.4, green: 0.7, blue: 1.0),
            textColor: Color(red: 0.7, green: 0.7, blue: 0.7)
        ),
        table: TableStyle(
            headerBackground: Color(red: 0.15, green: 0.15, blue: 0.17),
            backgroundStyle: .alternatingRows(
                even: Color(red: 0.1, green: 0.1, blue: 0.12),
                odd: .clear
            )
        )
    )

    static let minimalTheme = MarkdownTheme(
        bodyFont: .system(size: 16, design: .serif),
        paragraphSpacing: 14,
        codeBlock: CodeBlockStyle(
            backgroundColor: .clear,
            cornerRadius: 0,
            padding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        ),
        blockquote: BlockquoteStyle(
            borderColor: .secondary,
            borderWidth: 1,
            textColor: .secondary
        ),
        thematicBreak: ThematicBreakStyle(
            color: .secondary,
            height: 0.5,
            verticalPadding: 24
        )
    )
}
