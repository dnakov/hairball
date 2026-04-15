import XCTest
@testable import Hairball

final class ProcessorTests: XCTestCase {

    let parser = MarkdownParser()

    // MARK: - LatexTransformer

    func testInlineLatex() {
        let doc = parser.parse("The formula $E=mc^2$ is famous.")
        let processed = LatexTransformer().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .latex(let c) = $0 { return c == "E=mc^2" }; return false
        }), "Expected inline latex node, got: \(content)")
    }

    func testDisplayLatex() {
        let doc = parser.parse("$$\nx^2 + y^2 = z^2\n$$")
        let processed = LatexTransformer().process(doc)
        XCTAssertTrue(processed.blocks.contains(where: {
            if case .latexBlock = $0 { return true }; return false
        }), "Expected latexBlock, got: \(processed.blocks)")
    }

    func testEscapedDollar() {
        let doc = parser.parse("Price is \\$5")
        let processed = LatexTransformer().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        // Should NOT produce a latex node
        XCTAssertFalse(content.contains(where: {
            if case .latex = $0 { return true }; return false
        }))
    }

    // MARK: - AutoLinkTransformer

    func testAutoLinkDetection() {
        let doc = parser.parse("Visit https://example.com today")
        let processed = AutoLinkTransformer().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .link(let dest, _, _) = $0 { return dest == "https://example.com" }; return false
        }), "Expected auto-linked URL, got: \(content)")
    }

    func testAutoLinkPreservesExistingLinks() {
        let doc = parser.parse("[click](https://example.com)")
        let processed = AutoLinkTransformer().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        // Should still have exactly one link
        let linkCount = content.filter {
            if case .link = $0 { return true }; return false
        }.count
        XCTAssertEqual(linkCount, 1)
    }

    // MARK: - CitationProcessor

    func testFootnoteCitation() {
        let doc = parser.parse("See source[^1] for details.")
        let processed = CitationProcessor().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        XCTAssertTrue(content.contains(where: {
            if case .citation(let idx, _, _) = $0 { return idx == 1 }; return false
        }), "Expected citation with index 1, got: \(content)")
    }

    func testBracketLinkCitation() {
        let doc = parser.parse("See [1](https://example.com \"Example\") for details.")
        let processed = CitationProcessor().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }

        XCTAssertTrue(content.contains(where: {
            if case .citation(let idx, let url, let title) = $0 {
                return idx == 1 && url == "https://example.com" && title == "Example"
            }
            return false
        }), "Expected bracket citation, got: \(content)")
        XCTAssertEqual(processed.metadata["citation.1.url"], "https://example.com")
        XCTAssertEqual(processed.metadata["citation.1.title"], "Example")
    }

    // MARK: - DefaultMarkdownProcessor

    func testDefaultProcessorMergesTextNodes() {
        // Create a document with adjacent text nodes
        let doc = Document(blocks: [
            .paragraph(content: [.text("hello "), .text("world")])
        ])
        let processed = DefaultMarkdownProcessor().process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        // Should merge into one text node
        XCTAssertEqual(content.count, 1)
        if case .text(let s) = content[0] {
            XCTAssertEqual(s, "hello world")
        } else {
            XCTFail("Expected merged text node")
        }
    }

    // MARK: - CompositeProcessor

    func testCompositeProcessor() {
        let doc = parser.parse("Visit https://example.com and $E=mc^2$")
        let composite = CompositeProcessor([
            AutoLinkTransformer(),
            LatexTransformer(),
        ])
        let processed = composite.process(doc)
        guard case .paragraph(let content) = processed.blocks[0] else {
            XCTFail("Expected paragraph"); return
        }
        let hasLink = content.contains(where: { if case .link = $0 { return true }; return false })
        let hasLatex = content.contains(where: { if case .latex = $0 { return true }; return false })
        XCTAssertTrue(hasLink, "Expected auto-linked URL")
        XCTAssertTrue(hasLatex, "Expected inline latex")
    }

    // MARK: - BlockChunker

    func testBlockChunkerPerBlock() {
        let doc = Document(blocks: [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [.text("Text")]),
            .codeBlock(language: "swift", content: "let x = 1"),
        ])
        let chunks = MarkdownBlockChunker(strategy: .perBlock).chunk(doc)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].blocks.count, 1)
    }

    func testBlockChunkerGrouped() {
        let doc = Document(blocks: [
            .paragraph(content: [.text("1")]),
            .paragraph(content: [.text("2")]),
            .paragraph(content: [.text("3")]),
            .paragraph(content: [.text("4")]),
            .paragraph(content: [.text("5")]),
        ])
        let chunks = MarkdownBlockChunker(strategy: .grouped(maxBlocks: 2)).chunk(doc)
        XCTAssertEqual(chunks.count, 3) // 2+2+1
    }
}
