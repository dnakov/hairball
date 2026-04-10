import SwiftUI
import Hairball

// MARK: - ImageProvider Protocol

public protocol ImageProvider {
    associatedtype Body: View
    @ViewBuilder func makeImage(url: URL, title: String?, alt: [InlineNode]) -> Body
}

// MARK: - DefaultImageProvider (with caching)

public struct DefaultImageProvider: ImageProvider {
    public init() {}

    public func makeImage(url: URL, title: String?, alt: [InlineNode]) -> some View {
        CachedAsyncImageView(url: url)
    }
}

/// An AsyncImage replacement with in-memory caching.
/// Avoids re-downloading images when views are re-created during scroll.
private struct CachedAsyncImageView: View {
    let url: URL
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        Group {
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    SwiftUI.Text("Image failed to load")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            @unknown default:
                EmptyView()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check in-memory cache first
        if let cached = ImageCache.shared.image(for: url) {
            phase = .success(cached)
            return
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            let (data, _) = try await URLSession.shared.data(for: request)
            #if canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            let image = Image(uiImage: uiImage)
            #elseif canImport(AppKit)
            guard let nsImage = NSImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            let image = Image(nsImage: nsImage)
            #endif
            ImageCache.shared.store(image, for: url)
            phase = .success(image)
        } catch {
            phase = .failure(error)
        }
    }
}

/// Simple in-memory image cache. Avoids re-fetching images that were
/// already loaded when SwiftUI destroys and recreates views during scroll.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private var cache: [URL: Image] = [:]
    private let lock = NSLock()
    private let maxEntries = 100

    func image(for url: URL) -> Image? {
        lock.withLock { cache[url] }
    }

    func store(_ image: Image, for url: URL) {
        lock.withLock {
            // Simple LRU-ish: if full, clear oldest half
            if cache.count >= maxEntries {
                let keysToRemove = Array(cache.keys.prefix(maxEntries / 2))
                for key in keysToRemove {
                    cache.removeValue(forKey: key)
                }
            }
            cache[url] = image
        }
    }

    func clear() {
        lock.withLock { cache.removeAll() }
    }
}

// Workaround: AsyncImagePhase isn't directly constructible, so we define our own.
private enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

// MARK: - InlineImageProvider Protocol

public protocol InlineImageProvider {
    func makeImage(url: URL, title: String?, alt: String) -> SwiftUI.Text
}

// MARK: - DefaultInlineImageProvider

public struct DefaultInlineImageProvider: InlineImageProvider {
    public init() {}

    public func makeImage(url: URL, title: String?, alt: String) -> SwiftUI.Text {
        SwiftUI.Text(Image(systemName: "photo"))
    }
}

// MARK: - Type-erased wrappers

public struct AnyImageProvider: ImageProvider {
    private let _makeImage: (URL, String?, [InlineNode]) -> AnyView

    public init<P: ImageProvider>(_ provider: P) {
        _makeImage = { url, title, alt in
            AnyView(provider.makeImage(url: url, title: title, alt: alt))
        }
    }

    public func makeImage(url: URL, title: String?, alt: [InlineNode]) -> some View {
        _makeImage(url, title, alt)
    }
}

// MARK: - Environment Keys

private struct ImageProviderKey: EnvironmentKey {
    static let defaultValue: AnyImageProvider = AnyImageProvider(DefaultImageProvider())
}

private struct InlineImageProviderKey: EnvironmentKey {
    static let defaultValue: any InlineImageProvider = DefaultInlineImageProvider()
}

extension EnvironmentValues {
    public var imageProvider: AnyImageProvider {
        get { self[ImageProviderKey.self] }
        set { self[ImageProviderKey.self] = newValue }
    }

    public var inlineImageProvider: any InlineImageProvider {
        get { self[InlineImageProviderKey.self] }
        set { self[InlineImageProviderKey.self] = newValue }
    }
}

extension View {
    public func imageProvider(_ provider: some ImageProvider) -> some View {
        environment(\.imageProvider, AnyImageProvider(provider))
    }

    public func inlineImageProvider(_ provider: some InlineImageProvider) -> some View {
        environment(\.inlineImageProvider, provider)
    }
}
