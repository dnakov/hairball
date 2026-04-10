import XCTest
@testable import Hairball

final class WalkerTests: XCTestCase {

    // MARK: - MarkupWalker

    func testWalkerVisitsAllBlocks() {
        let doc = Document(blocks: [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [.text("Body")]),
            .codeBlock(language: "swift", content: "let x = 1"),
            .thematicBreak,
            .blockQuote(children: [
                .paragraph(content: [.text("Quoted")])
            ]),
        ])

        let counter = BlockCounter()
        counter.walk(document: doc)
        XCTAssertEqual(counter.headingCount, 1)
        XCTAssertEqual(counter.paragraphCount, 2) // body + quoted
        XCTAssertEqual(counter.codeBlockCount, 1)
        XCTAssertEqual(counter.thematicBreakCount, 1)
        XCTAssertEqual(counter.blockQuoteCount, 1)
    }

    func testWalkerVisitsInlines() {
        let doc = Document(blocks: [
            .paragraph(content: [
                .text("Hello "),
                .strong(children: [.text("bold ")]),
                .emphasis(children: [.text("italic")]),
            ])
        ])

        let counter = InlineCounter()
        counter.walk(document: doc)
        XCTAssertEqual(counter.textCount, 3)
        XCTAssertEqual(counter.strongCount, 1)
        XCTAssertEqual(counter.emphasisCount, 1)
    }

    func testWalkerVisitsNestedLists() {
        let doc = Document(blocks: [
            .unorderedList(tight: true, items: [
                ListItem(children: [
                    .paragraph(content: [.text("Item 1")]),
                    .unorderedList(tight: true, items: [
                        ListItem(children: [
                            .paragraph(content: [.text("Nested")])
                        ])
                    ])
                ])
            ])
        ])

        let counter = BlockCounter()
        counter.walk(document: doc)
        XCTAssertEqual(counter.paragraphCount, 2)
        XCTAssertEqual(counter.listCount, 2)
    }
}

// MARK: - Test Helpers

private class BlockCounter: MarkupWalker {
    var headingCount = 0
    var paragraphCount = 0
    var codeBlockCount = 0
    var thematicBreakCount = 0
    var blockQuoteCount = 0
    var listCount = 0

    override func visitHeading(level: Int, content: [InlineNode]) {
        headingCount += 1
        for node in content { walk(inline: node) }
    }
    override func visitParagraph(content: [InlineNode]) {
        paragraphCount += 1
        for node in content { walk(inline: node) }
    }
    override func visitCodeBlock(language: String?, content: String) {
        codeBlockCount += 1
    }
    override func visitThematicBreak() {
        thematicBreakCount += 1
    }
    override func visitBlockQuote(children: [BlockNode]) {
        blockQuoteCount += 1
        for child in children { walk(block: child) }
    }
    override func visitUnorderedList(tight: Bool, items: [ListItem]) {
        listCount += 1
        for item in items { for child in item.children { walk(block: child) } }
    }
    override func visitOrderedList(startIndex: Int, tight: Bool, items: [ListItem]) {
        listCount += 1
        for item in items { for child in item.children { walk(block: child) } }
    }
}

private class InlineCounter: MarkupWalker {
    var textCount = 0
    var strongCount = 0
    var emphasisCount = 0

    override func visitText(_ text: String) {
        textCount += 1
    }
    override func visitStrong(children: [InlineNode]) {
        strongCount += 1
        for child in children { walk(inline: child) }
    }
    override func visitEmphasis(children: [InlineNode]) {
        emphasisCount += 1
        for child in children { walk(inline: child) }
    }
}
