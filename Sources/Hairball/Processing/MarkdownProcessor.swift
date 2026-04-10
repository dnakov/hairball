import Foundation

// MARK: - MarkdownProcessor Protocol

public protocol MarkdownProcessor: Sendable {
    func process(_ document: Document) -> Document
}

// MARK: - CompositeProcessor

public struct CompositeProcessor: MarkdownProcessor {
    private let processors: [any MarkdownProcessor]

    public init(_ processors: [any MarkdownProcessor]) {
        self.processors = processors
    }

    public init(_ processors: any MarkdownProcessor...) {
        self.processors = processors
    }

    public func process(_ document: Document) -> Document {
        processors.reduce(document) { doc, processor in
            processor.process(doc)
        }
    }
}

// MARK: - Convenience

extension Array where Element == any MarkdownProcessor {
    public func combined() -> CompositeProcessor {
        CompositeProcessor(self)
    }
}
