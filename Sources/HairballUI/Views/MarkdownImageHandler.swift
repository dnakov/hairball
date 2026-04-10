import SwiftUI
import Hairball

/// Handles image loading, caching, and display for markdown images.
/// Matches `MarkdownImageHandler` from the original binary.
public final class MarkdownImageHandler: ObservableObject {
    @Published public var loadedImages: [String: Image] = [:]
    @Published public var loadingStates: [String: LoadingState] = [:]

    public enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public init() {}

    /// Load an image from a URL string.
    @MainActor
    public func loadImage(from source: String) async {
        guard let url = URL(string: source) else {
            loadingStates[source] = .failed("Invalid URL")
            return
        }

        loadingStates[source] = .loading

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                loadedImages[source] = Image(uiImage: uiImage)
                loadingStates[source] = .loaded
            } else {
                loadingStates[source] = .failed("Invalid image data")
            }
            #elseif canImport(AppKit)
            if let nsImage = NSImage(data: data) {
                loadedImages[source] = Image(nsImage: nsImage)
                loadingStates[source] = .loaded
            } else {
                loadingStates[source] = .failed("Invalid image data")
            }
            #endif
        } catch {
            loadingStates[source] = .failed(error.localizedDescription)
        }
    }

    /// Get the current image for a source, or nil if not loaded.
    public func image(for source: String) -> Image? {
        loadedImages[source]
    }

    /// Get the loading state for a source.
    public func state(for source: String) -> LoadingState {
        loadingStates[source] ?? .idle
    }

    /// Preload images for all image sources in a document.
    @MainActor
    public func preloadImages(from document: Document) async {
        let sources = extractImageSources(from: document.blocks)
        await withTaskGroup(of: Void.self) { group in
            for source in sources {
                group.addTask {
                    await self.loadImage(from: source)
                }
            }
        }
    }

    private func extractImageSources(from blocks: [BlockNode]) -> [String] {
        var sources: [String] = []
        for block in blocks {
            switch block {
            case .document(let children), .blockQuote(let children), .blockDirective(_, _, let children):
                sources.append(contentsOf: extractImageSources(from: children))
            case .paragraph(let content), .heading(_, let content):
                sources.append(contentsOf: extractInlineImageSources(from: content))
            case .orderedList(_, _, let items), .unorderedList(_, let items):
                for item in items {
                    sources.append(contentsOf: extractImageSources(from: item.children))
                }
            default:
                break
            }
        }
        return sources
    }

    private func extractInlineImageSources(from inlines: [InlineNode]) -> [String] {
        var sources: [String] = []
        for inline in inlines {
            switch inline {
            case .image(let source, _, _):
                sources.append(source)
            case .emphasis(let children), .strong(let children), .strikethrough(let children):
                sources.append(contentsOf: extractInlineImageSources(from: children))
            case .link(_, _, let children):
                sources.append(contentsOf: extractInlineImageSources(from: children))
            default:
                break
            }
        }
        return sources
    }
}

// MARK: - Environment Key

private struct MarkdownImageHandlerKey: EnvironmentKey {
    static let defaultValue: MarkdownImageHandler = MarkdownImageHandler()
}

extension EnvironmentValues {
    public var markdownImageHandler: MarkdownImageHandler {
        get { self[MarkdownImageHandlerKey.self] }
        set { self[MarkdownImageHandlerKey.self] = newValue }
    }
}

extension View {
    public func markdownImageHandler(_ handler: MarkdownImageHandler) -> some View {
        environment(\.markdownImageHandler, handler)
    }
}
