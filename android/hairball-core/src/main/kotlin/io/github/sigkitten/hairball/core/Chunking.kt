package io.github.sigkitten.hairball.core

data class MarkdownBlockCollection(
    val id: String,
    val blocks: List<BlockNode>,
)

sealed interface ChunkingStrategy {
    data object PerBlock : ChunkingStrategy
    data class Grouped(val maxBlocks: Int) : ChunkingStrategy
    data object Paragraph : ChunkingStrategy
}

class MarkdownBlockChunker(
    private val strategy: ChunkingStrategy = ChunkingStrategy.Paragraph,
) {
    fun chunk(document: Document): List<MarkdownBlockCollection> =
        when (strategy) {
            is ChunkingStrategy.PerBlock -> chunkPerBlock(document.blocks)
            is ChunkingStrategy.Grouped -> chunkGrouped(document.blocks, strategy.maxBlocks.coerceAtLeast(1))
            is ChunkingStrategy.Paragraph -> chunkParagraphs(document.blocks)
        }

    private fun chunkPerBlock(blocks: List<BlockNode>): List<MarkdownBlockCollection> {
        val counts = mutableMapOf<Int, Int>()
        return blocks.map { block ->
            val hash = block.hashCode()
            val count = counts.getOrDefault(hash, 0)
            counts[hash] = count + 1
            MarkdownBlockCollection(id = "block-$hash-$count", blocks = listOf(block))
        }
    }

    private fun chunkGrouped(blocks: List<BlockNode>, maxBlocks: Int): List<MarkdownBlockCollection> {
        val result = mutableListOf<MarkdownBlockCollection>()
        val idCounts = mutableMapOf<Int, Int>()
        var index = 0
        while (index < blocks.size) {
            val slice = blocks.subList(index, minOf(index + maxBlocks, blocks.size))
            val hash = slice.fold(1) { acc, block -> 31 * acc + block.hashCode() }
            val count = idCounts.getOrDefault(hash, 0)
            idCounts[hash] = count + 1
            result += MarkdownBlockCollection(id = "group-$hash-$count", blocks = slice.toList())
            index += maxBlocks
        }
        return result
    }

    private fun chunkParagraphs(blocks: List<BlockNode>): List<MarkdownBlockCollection> {
        val result = mutableListOf<MarkdownBlockCollection>()
        val current = mutableListOf<BlockNode>()
        val idCounts = mutableMapOf<Int, Int>()

        fun flush() {
            if (current.isEmpty()) return
            val hash = current.fold(1) { acc, block -> 31 * acc + block.hashCode() }
            val count = idCounts.getOrDefault(hash, 0)
            idCounts[hash] = count + 1
            result += MarkdownBlockCollection(id = "para-$hash-$count", blocks = current.toList())
            current.clear()
        }

        for (block in blocks) {
            when (block) {
                is BlockNode.Heading -> {
                    flush()
                    current += block
                }
                is BlockNode.ThematicBreak -> {
                    flush()
                    val hash = block.hashCode()
                    val count = idCounts.getOrDefault(hash, 0)
                    idCounts[hash] = count + 1
                    result += MarkdownBlockCollection(id = "para-$hash-$count", blocks = listOf(block))
                }
                is BlockNode.Paragraph, is BlockNode.DocumentBlock -> current += block
                else -> {
                    if (current.singleOrNull() is BlockNode.Heading) {
                        current += block
                        flush()
                    } else {
                        flush()
                        current += block
                        flush()
                    }
                }
            }
        }
        flush()
        return result
    }
}
