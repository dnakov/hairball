import XCTest
@testable import Hairball

final class BlockquoteTest: XCTestCase {
    func testBlockquoteParsing() {
        let parser = MarkdownParser()
        let doc = parser.parse("> This is a quote")
        guard case .blockQuote = doc.blocks.first else {
            XCTFail("Expected blockQuote, got: \(doc.blocks)")
            return
        }
    }

    func testBlockquoteFromDedentedContent() {
        // Simulates what the example app does — multiline string with common indent
        let raw = """
            ## Section

            Some text.

            > This is a **blockquote** that should render.

            More text.
            """
        // Dedent like the example does
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let minIndent = nonEmpty.map { $0.prefix(while: { $0 == " " }).count }.min() ?? 0
        let dedented = lines.map { $0.count >= minIndent ? String($0.dropFirst(minIndent)) : $0 }.joined(separator: "\n")

        print("DEDENTED:\n\(dedented)")

        let parser = MarkdownParser()
        let doc = parser.parse(dedented)
        print("BLOCKS: \(doc.blocks.map { "\($0)".prefix(80) })")

        let hasBlockQuote = doc.blocks.contains(where: { if case .blockQuote = $0 { return true }; return false })
        XCTAssertTrue(hasBlockQuote, "Expected blockquote in parsed blocks")
    }
}
