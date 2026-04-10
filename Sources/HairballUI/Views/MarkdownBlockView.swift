import SwiftUI
import Hairball

/// Wraps a single block node with theme-aware spacing and animation support.
/// Matches `MarkdownBlockView` from the original binary.
/// Use this when you need per-block control over transitions and animations.
public struct MarkdownBlockView: View {
    @Environment(\.markdownTheme) private var theme

    private let block: BlockNode
    private let transition: AnyTransition
    private let animation: Animation?

    public init(
        block: BlockNode,
        transition: AnyTransition = .identity,
        animation: Animation? = nil
    ) {
        self.block = block
        self.transition = transition
        self.animation = animation
    }

    public var body: some View {
        BlockNodeView(node: block)
            .transition(transition)
            .animation(animation, value: block)
    }
}

// MarkdownBlockCollection is defined in Hairball/Processing/BlockChunker.swift

/// A view that renders a `MarkdownBlockCollection` with per-block animation support.
public struct AnimatedMarkdownBlocksView: View {
    @Environment(\.markdownTheme) private var theme

    private let collections: [MarkdownBlockCollection]
    private let blockTransition: AnyTransition
    private let blockAnimation: Animation?

    public init(
        collections: [MarkdownBlockCollection],
        blockTransition: AnyTransition = .identity,
        blockAnimation: Animation? = nil
    ) {
        self.collections = collections
        self.blockTransition = blockTransition
        self.blockAnimation = blockAnimation
    }

    /// Convenience init from a flat list of blocks (auto-chunks with one block per collection).
    public init(
        blocks: [BlockNode],
        blockTransition: AnyTransition = .identity,
        blockAnimation: Animation? = nil
    ) {
        self.collections = blocks.enumerated().map { index, block in
            MarkdownBlockCollection(id: "block-\(index)", blocks: [block])
        }
        self.blockTransition = blockTransition
        self.blockAnimation = blockAnimation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.paragraphSpacing) {
            ForEach(collections) { collection in
                ForEach(Array(collection.blocks.enumerated()), id: \.offset) { _, block in
                    BlockNodeView(node: block)
                        .transition(blockTransition)
                        .animation(blockAnimation, value: collection.id)
                }
            }
        }
    }
}
