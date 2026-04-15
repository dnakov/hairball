import SwiftUI
import Hairball
import HairballUI

struct ResultBuilderDSLView: View {
    @State private var showOptional = true
    @State private var itemCount = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Toggle("Optional section", isOn: $showOptional)
                    Stepper("Items: \(itemCount)", value: $itemCount, in: 1...6)
                }
                .padding(.horizontal)

                Divider()

                MarkdownView(document: buildDocument())
                    .padding()
                    .animation(.easeInOut, value: showOptional)
                    .animation(.easeInOut, value: itemCount)
            }
        }
        .navigationTitle("DSL Builder")
    }

    private func buildDocument() -> Document {
        var blocks: [BlockNode] = []

        blocks.append(.heading(level: 1, content: [.text("Programmatic Markdown")]))
        blocks.append(.paragraph(content: [.text("Built with Swift code, not a markdown string.")]))

        blocks.append(.heading(level: 2, content: [.text("Code Example")]))
        blocks.append(.codeBlock(language: "swift", content: """
        let doc = Document(blocks: [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [.text("Built with Swift!")]),
        ])
        MarkdownView(document: doc)
        """))

        if showOptional {
            blocks.append(.heading(level: 2, content: [.text("Optional Section")]))
            blocks.append(.paragraph(content: [
                .text("This section toggles on and off."),
            ]))
            blocks.append(.blockQuote(children: [
                .paragraph(content: [.text("Dynamic content is first-class.")])
            ]))
        }

        blocks.append(.heading(level: 2, content: [.text("Dynamic Items (\(itemCount))")]))

        for i in 1...itemCount {
            blocks.append(.paragraph(content: [
                .text("Item \(i): "),
                .strong(children: [.text("Dynamic #\(i)")]),
                .text(" from a range."),
            ]))
        }

        blocks.append(.heading(level: 3, content: [.text("Inline Formatting")]))
        blocks.append(.paragraph(content: [
            .text("Mix "), .strong(children: [.text("bold")]),
            .text(", "), .emphasis(children: [.text("italic")]),
            .text(", "), .inlineCode("code"),
            .text(", and "), .link(destination: "https://example.com", title: nil, children: [.text("links")]),
            .text(" in one paragraph."),
        ]))

        blocks.append(.thematicBreak)

        blocks.append(.unorderedList(tight: true, items: [
            ListItem(children: [.paragraph(content: [.text("Parse markdown")])], checkbox: .checked),
            ListItem(children: [.paragraph(content: [.text("Render to SwiftUI")])], checkbox: .checked),
            ListItem(children: [.paragraph(content: [.text("Ship it")])], checkbox: .unchecked),
        ]))

        return Document(blocks: blocks)
    }
}
