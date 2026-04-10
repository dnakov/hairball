import XCTest
@testable import Hairball

final class LatexTests: XCTestCase {
    func testDisplayMathParsing() {
        let parser = MarkdownParser()
        let transformer = LatexTransformer()

        let input = """
        Inline: $E = mc^2$

        $$
        f(x) = x^2
        $$
        """

        let doc = parser.parse(input)
        print("=== BEFORE TRANSFORM ===")
        for (i, block) in doc.blocks.enumerated() {
            print("Block \(i): \(block)")
        }

        let processed = transformer.process(doc)
        print("\n=== AFTER TRANSFORM ===")
        for (i, block) in processed.blocks.enumerated() {
            print("Block \(i): \(block)")
        }

        // Check that we got a latexBlock somewhere
        let hasLatexBlock = processed.blocks.contains { block in
            if case .latexBlock = block { return true }
            return false
        }
        XCTAssertTrue(hasLatexBlock, "Should have a latexBlock after transform. Got: \(processed.blocks)")
    }
}
