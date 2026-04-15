import XCTest
import SwiftUI
@testable import Hairball
@testable import HairballUI

final class InlineTextRendererTests: XCTestCase {
    func testSingleBacktickInlineCodeUsesThemeColorsAgainstBodyStyle() {
        let theme = MarkdownTheme(
            bodyFont: .system(size: 14),
            foregroundColor: .blue,
            inlineCode: InlineCodeStyle(
                backgroundColor: .yellow,
                textColor: .red,
                font: .system(size: 15, design: .monospaced)
            )
        )

        let parser = MarkdownParser()
        let document = parser.parse("prefix `code` suffix")
        guard case .paragraph(let content) = document.blocks.first else {
            XCTFail("Expected paragraph"); return
        }

        let rendered = InlineTextRenderer(theme: theme).renderToAttributedString(
            content,
            baseStyle: InlineStyle(
                font: theme.bodyFont,
                foregroundColor: theme.bodyTextColor
            )
        )

        let prefixRange = rendered.range(of: "prefix")
        XCTAssertNotNil(prefixRange)

        let codeRange = rendered.range(of: "code")
        XCTAssertNotNil(codeRange)

        guard let prefixRange else { return }
        guard let codeRange else { return }
        let prefixSlice = rendered[prefixRange]
        let codeSlice = rendered[codeRange]

        XCTAssertEqual(prefixSlice.foregroundColor, .blue)
        XCTAssertEqual(codeSlice.foregroundColor, .red)
        XCTAssertEqual(codeSlice.backgroundColor, .yellow)
    }
}
