import XCTest
@testable import Hairball

final class ASTTests: XCTestCase {

    // MARK: - BlockNode Equatable

    func testBlockNodeEquality() {
        let a = BlockNode.heading(level: 1, content: [.text("Hello")])
        let b = BlockNode.heading(level: 1, content: [.text("Hello")])
        let c = BlockNode.heading(level: 2, content: [.text("Hello")])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - InlineNode Equatable

    func testInlineNodeEquality() {
        XCTAssertEqual(InlineNode.text("hi"), InlineNode.text("hi"))
        XCTAssertNotEqual(InlineNode.text("hi"), InlineNode.text("bye"))
        XCTAssertEqual(
            InlineNode.strong(children: [.text("bold")]),
            InlineNode.strong(children: [.text("bold")])
        )
    }

    // MARK: - Document

    func testDocumentPlainText() {
        let doc = Document(blocks: [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [
                .text("Hello "),
                .strong(children: [.text("world")]),
            ]),
        ])
        let plain = doc.plainText
        XCTAssertTrue(plain.contains("Title"))
        XCTAssertTrue(plain.contains("Hello"))
        XCTAssertTrue(plain.contains("world"))
    }

    func testDocumentMetadata() {
        var doc = Document(blocks: [], metadata: ["key": "value"])
        XCTAssertEqual(doc.metadata["key"], "value")
        doc.metadata["another"] = "test"
        XCTAssertEqual(doc.metadata["another"], "test")
    }

    // MARK: - IdentifiedBlock

    func testIdentifiedBlockStableIDs() {
        let blocks: [BlockNode] = [
            .heading(level: 1, content: [.text("A")]),
            .paragraph(content: [.text("B")]),
            .heading(level: 1, content: [.text("A")]), // duplicate
        ]
        let identified = IdentifiedBlock.identify(blocks)
        XCTAssertEqual(identified.count, 3)
        // First and third have same content but different IDs (tiebreaker)
        XCTAssertNotEqual(identified[0].id, identified[2].id)
        // Same content parsed twice should produce same IDs
        let identified2 = IdentifiedBlock.identify(blocks)
        XCTAssertEqual(identified[0].id, identified2[0].id)
        XCTAssertEqual(identified[1].id, identified2[1].id)
    }

    // MARK: - ListItem

    func testListItemCheckbox() {
        let checked = ListItem(children: [.paragraph(content: [.text("done")])], checkbox: .checked)
        let unchecked = ListItem(children: [.paragraph(content: [.text("todo")])], checkbox: .unchecked)
        let plain = ListItem(children: [.paragraph(content: [.text("item")])])
        XCTAssertEqual(checked.checkbox, .checked)
        XCTAssertEqual(unchecked.checkbox, .unchecked)
        XCTAssertNil(plain.checkbox)
    }

    // MARK: - Table types

    func testTableColumnAlignment() {
        XCTAssertNotEqual(TableColumnAlignment.left, TableColumnAlignment.right)
        XCTAssertEqual(TableColumnAlignment.center, TableColumnAlignment.center)
    }

    func testTableRowCells() {
        let row = MarkdownTableRow(cells: [
            MarkdownTableCell(content: [.text("A")]),
            MarkdownTableCell(content: [.text("B")]),
        ])
        XCTAssertEqual(row.cells.count, 2)
    }

    // MARK: - Hashable

    func testBlockNodeHashable() {
        let set: Set<BlockNode> = [
            .thematicBreak,
            .thematicBreak,
            .heading(level: 1, content: [.text("A")]),
        ]
        XCTAssertEqual(set.count, 2)
    }

    func testInlineNodeHashable() {
        let set: Set<InlineNode> = [
            .text("hello"),
            .text("hello"),
            .text("world"),
        ]
        XCTAssertEqual(set.count, 2)
    }
}
