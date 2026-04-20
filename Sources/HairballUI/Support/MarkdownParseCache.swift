import Foundation
import Hairball

/// Shared LRU cache for parse-and-process output so that re-constructing a
/// `MarkdownView` with the same markdown doesn't re-run the parser and the
/// processor chain on every SwiftUI body evaluation.
///
/// SwiftUI `View` values are rebuilt constantly — every time a parent's body
/// fires, each child's init is called, and the old init path in
/// `MarkdownView` parsed the string and walked the processor chain there.
/// For a multi-KB assistant reply, that ran on every streaming token and on
/// every scroll frame.
///
/// Keying: (markdown, parseOptions.rawValue, processorFingerprint).
///
/// `processorFingerprint` is a concatenation of processor type names. This
/// is safe for the built-in processors in this package — they are all
/// stateless structs (`DefaultMarkdownProcessor`, `LatexTransformer`,
/// `AutoLinkTransformer`, `CitationProcessor`). Callers with stateful
/// processors should prefer `MarkdownView(document:)` and drive
/// cache-busting themselves, since two instances of a stateful processor
/// may produce different outputs for identical inputs.
final class MarkdownParseCache: @unchecked Sendable {
    static let shared = MarkdownParseCache()

    private struct Key: Hashable {
        let markdown: String
        let optionsRawValue: Int
        let processorFingerprint: String
    }

    private let lock = NSLock()
    private var cache: [Key: Document] = [:]
    // Track insertion order so we can evict the oldest entry when we
    // exceed `maxEntries`. Small cost but keeps memory bounded for long
    // sessions with many distinct markdown strings.
    private var insertionOrder: [Key] = []
    private let maxEntries: Int

    init(maxEntries: Int = 128) {
        self.maxEntries = maxEntries
    }

    func document(
        for markdown: String,
        options: ParseOptions,
        processors: [any MarkdownProcessor]
    ) -> Document {
        let key = Key(
            markdown: markdown,
            optionsRawValue: options.rawValue,
            processorFingerprint: Self.fingerprint(processors)
        )

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parse + process outside the lock so concurrent callers don't
        // serialize on one slow document. Worst case: two callers parse
        // the same string once — harmless.
        var document = MarkdownParser(options: options).parse(markdown)
        for processor in processors {
            document = processor.process(document)
        }

        lock.lock()
        if cache[key] == nil {
            cache[key] = document
            insertionOrder.append(key)
            if insertionOrder.count > maxEntries {
                let evict = insertionOrder.removeFirst()
                cache.removeValue(forKey: evict)
            }
        }
        lock.unlock()

        return document
    }

    func clear() {
        lock.lock()
        cache.removeAll()
        insertionOrder.removeAll()
        lock.unlock()
    }

    private static func fingerprint(_ processors: [any MarkdownProcessor]) -> String {
        if processors.isEmpty { return "" }
        var parts: [String] = []
        parts.reserveCapacity(processors.count)
        for processor in processors {
            parts.append(String(reflecting: type(of: processor)))
        }
        return parts.joined(separator: "|")
    }
}
