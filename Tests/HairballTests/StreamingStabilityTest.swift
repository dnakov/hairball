import XCTest
@testable import Hairball

final class StreamingStabilityTest: XCTestCase {
    let parser = MarkdownParser()

    func testPartialCodeFence() {
        // Simulate streaming a code block token by token
        let stages = [
            "Hello world\n",
            "Hello world\n```",
            "Hello world\n```swift",
            "Hello world\n```swift\n",
            "Hello world\n```swift\nlet x = 42",
            "Hello world\n```swift\nlet x = 42\n",
            "Hello world\n```swift\nlet x = 42\n```",
        ]
        for (i, text) in stages.enumerated() {
            let doc = parser.parse(text)
            let types = doc.blocks.map { block -> String in
                switch block {
                case .paragraph: return "p"
                case .codeBlock: return "code"
                case .heading: return "h"
                case .thematicBreak: return "hr"
                default: return "other"
                }
            }
            print("Stage \(i): \(types) — \(text.suffix(20).debugDescription)")
        }
    }

    func testPartialTable() {
        let stages = [
            "Text\n",
            "Text\n| A | B |",
            "Text\n| A | B |\n",
            "Text\n| A | B |\n|---|---|",
            "Text\n| A | B |\n|---|---|\n| 1 | 2 |",
        ]
        for (i, text) in stages.enumerated() {
            let doc = parser.parse(text)
            let types = doc.blocks.map { block -> String in
                switch block {
                case .paragraph: return "p"
                case .table: return "table"
                default: return "other"
                }
            }
            print("Stage \(i): \(types)")
        }
    }
}
