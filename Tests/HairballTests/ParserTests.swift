import XCTest
@testable import Hairball

final class ParserTests: XCTestCase {

    let parser = MarkdownParser()

    // MARK: - Headings

    func testHeadings() {
        let doc = parser.parse("# H1\n## H2\n### H3")
        XCTAssertEqual(doc.blocks.count, 3)
        if case .heading(let level, let content) = doc.blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(content, [.text("H1")])
        } else { XCTFail("Expected heading") }
        if case .heading(let level, _) = doc.blocks[1] {
            XCTAssertEqual(level, 2)
        } else { XCTFail("Expected heading") }
        if case .heading(let level, _) = doc.blocks[2] {
            XCTAssertEqual(level, 3)
        } else { XCTFail("Expected heading") }
    }

    // MARK: - Paragraphs and inline formatting

    func testParagraphWithInlineFormatting() {
        let doc = parser.parse("Hello **bold** and *italic* and `code`")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .strong = $0 { return true }; return false
        }))
        XCTAssertTrue(content.contains(where: {
            if case .emphasis = $0 { return true }; return false
        }))
        XCTAssertTrue(content.contains(where: {
            if case .inlineCode = $0 { return true }; return false
        }))
    }

    func testParagraphWithSingleBacktickInlineCode() {
        let doc = parser.parse("Use `code` here")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }

        XCTAssertEqual(content, [
            .text("Use "),
            .inlineCode("code"),
            .text(" here"),
        ])
    }

    func testParagraphWithDoubleBacktickInlineCode() {
        let doc = parser.parse("Use ``code`` here")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }

        XCTAssertEqual(content, [
            .text("Use "),
            .inlineCode("code"),
            .text(" here"),
        ])
    }

    func testBareDoubleBackticksRemainText() {
        let doc = parser.parse("``")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }

        XCTAssertEqual(content, [.text("``")])
    }

    func testBlockDirectivesEnabledByDefault() {
        let doc = MarkdownParser().parse("""
        @Tutorial {
        Body
        }
        """)

        guard case .blockDirective(let name, _, let children) = doc.blocks.first else {
            XCTFail("Expected block directive"); return
        }

        XCTAssertEqual(name, "Tutorial")
        XCTAssertEqual(children.count, 1)
    }

    func testBlockDirectivesCanBeDisabled() {
        let doc = MarkdownParser(options: []).parse("""
        @Tutorial {
        Body
        }
        """)

        guard case .paragraph(let content) = doc.blocks.first else {
            XCTFail("Expected paragraph when directives are disabled"); return
        }

        let text = content.compactMap { node -> String? in
            if case .text(let value) = node { return value }
            return nil
        }.joined()
        XCTAssertTrue(text.contains("@Tutorial"))
    }

    // MARK: - Code blocks

    func testFencedCodeBlock() {
        let doc = parser.parse("```swift\nlet x = 42\n```")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .codeBlock(let lang, let code) = doc.blocks[0] else {
            XCTFail("Expected code block"); return
        }
        XCTAssertEqual(lang, "swift")
        XCTAssertTrue(code.contains("let x = 42"))
    }

    func testCodeBlockNoLanguage() {
        let doc = parser.parse("```\nhello\n```")
        guard case .codeBlock(let lang, _) = doc.blocks[0] else {
            XCTFail("Expected code block"); return
        }
        XCTAssertNil(lang)
    }

    // MARK: - Lists

    func testUnorderedList() {
        let doc = parser.parse("- one\n- two\n- three")
        guard case .unorderedList(_, let items) = doc.blocks[0] else {
            XCTFail("Expected unordered list"); return
        }
        XCTAssertEqual(items.count, 3)
    }

    func testOrderedList() {
        let doc = parser.parse("1. first\n2. second")
        guard case .orderedList(let start, _, let items) = doc.blocks[0] else {
            XCTFail("Expected ordered list"); return
        }
        XCTAssertEqual(start, 1)
        XCTAssertEqual(items.count, 2)
    }

    func testTaskList() {
        let doc = parser.parse("- [x] done\n- [ ] todo")
        guard case .unorderedList(_, let items) = doc.blocks[0] else {
            XCTFail("Expected list"); return
        }
        XCTAssertEqual(items[0].checkbox, .checked)
        XCTAssertEqual(items[1].checkbox, .unchecked)
    }

    // MARK: - Block quotes

    func testBlockQuote() {
        let doc = parser.parse("> quoted text")
        guard case .blockQuote(let children) = doc.blocks[0] else {
            XCTFail("Expected blockquote"); return
        }
        XCTAssertEqual(children.count, 1)
    }

    // MARK: - Tables

    func testTable() {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        | 3 | 4 |
        """
        let doc = parser.parse(md)
        guard case .table(let alignments, let head, let body) = doc.blocks[0] else {
            XCTFail("Expected table"); return
        }
        XCTAssertEqual(alignments.count, 2)
        XCTAssertEqual(head.cells.count, 2)
        XCTAssertEqual(body.count, 2)
    }

    // MARK: - Thematic break

    func testThematicBreak() {
        let doc = parser.parse("---")
        XCTAssertEqual(doc.blocks[0], .thematicBreak)
    }

    // MARK: - Links and images

    func testLink() {
        let doc = parser.parse("[click](https://example.com)")
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .link(let dest, _, _) = $0 { return dest == "https://example.com" }; return false
        }))
    }

    func testImage() {
        let doc = parser.parse("![alt](https://img.png)")
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .image(let src, _, _) = $0 { return src == "https://img.png" }; return false
        }))
    }

    // MARK: - Strikethrough

    func testStrikethrough() {
        let doc = parser.parse("~~deleted~~")
        guard case .paragraph(let content) = doc.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .strikethrough = $0 { return true }; return false
        }))
    }

    // MARK: - Document

    func testPlainText() {
        let doc = parser.parse("# Hello\n\nworld **bold**")
        XCTAssertTrue(doc.plainText.contains("Hello"))
        XCTAssertTrue(doc.plainText.contains("world"))
        XCTAssertTrue(doc.plainText.contains("bold"))
    }

    func testEmptyDocument() {
        let doc = parser.parse("")
        XCTAssertTrue(doc.blocks.isEmpty)
    }
}
