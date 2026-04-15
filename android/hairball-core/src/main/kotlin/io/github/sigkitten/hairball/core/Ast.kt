package io.github.sigkitten.hairball.core

data class Document(
    val blocks: List<BlockNode>,
    val metadata: Map<String, String> = emptyMap(),
) {
    val plainText: String
        get() = blocks.joinToString("\n") { it.plainText }
}

enum class CheckboxState {
    Checked,
    Unchecked,
}

data class ListItem(
    val children: List<BlockNode>,
    val checkbox: CheckboxState? = null,
)

enum class MarkdownTableColumnAlignment {
    Left,
    Center,
    Right,
    None,
}

data class MarkdownTableCell(
    val content: List<InlineNode>,
)

data class MarkdownTableRow(
    val cells: List<MarkdownTableCell>,
)

data class IdentifiedBlock(
    val id: String,
    val block: BlockNode,
) {
    companion object {
        fun identify(blocks: List<BlockNode>): List<IdentifiedBlock> =
            blocks.mapIndexed { index, block ->
                IdentifiedBlock(id = "${block.typePrefix()}-$index", block = block)
            }
    }
}

sealed interface BlockNode {
    val plainText: String

    data class DocumentBlock(val children: List<BlockNode>) : BlockNode {
        override val plainText: String = children.joinToString("\n") { it.plainText }
    }

    data class Heading(val level: Int, val content: List<InlineNode>) : BlockNode {
        override val plainText: String = content.plainText
    }

    data class Paragraph(val content: List<InlineNode>) : BlockNode {
        override val plainText: String = content.plainText
    }

    data class CodeBlock(val language: String?, val content: String) : BlockNode {
        override val plainText: String = content
    }

    data class BlockQuote(val children: List<BlockNode>) : BlockNode {
        override val plainText: String = children.joinToString("\n") { it.plainText }
    }

    data class OrderedList(val startIndex: Int, val tight: Boolean, val items: List<ListItem>) : BlockNode {
        override val plainText: String = items.joinToString("\n") { item ->
            item.children.joinToString("\n") { it.plainText }
        }
    }

    data class UnorderedList(val tight: Boolean, val items: List<ListItem>) : BlockNode {
        override val plainText: String = items.joinToString("\n") { item ->
            item.children.joinToString("\n") { it.plainText }
        }
    }

    data class Table(
        val columnAlignments: List<MarkdownTableColumnAlignment>,
        val head: MarkdownTableRow,
        val body: List<MarkdownTableRow>,
    ) : BlockNode {
        override val plainText: String =
            buildString {
                append(head.cells.joinToString("\t") { it.content.plainText })
                if (body.isNotEmpty()) {
                    append('\n')
                    append(body.joinToString("\n") { row -> row.cells.joinToString("\t") { it.content.plainText } })
                }
            }
    }

    data object ThematicBreak : BlockNode {
        override val plainText: String = ""
    }

    data class HtmlBlock(val content: String) : BlockNode {
        override val plainText: String = content
    }

    data class CustomBlock(val name: String, val content: String) : BlockNode {
        override val plainText: String = content
    }

    data class LatexBlock(val content: String) : BlockNode {
        override val plainText: String = content
    }

    data class BlockDirective(val name: String, val arguments: String?, val children: List<BlockNode>) : BlockNode {
        override val plainText: String = children.joinToString("\n") { it.plainText }
    }
}

sealed interface InlineNode {
    val plainText: String

    data class Text(val value: String) : InlineNode {
        override val plainText: String = value
    }

    data class Emphasis(val children: List<InlineNode>) : InlineNode {
        override val plainText: String = children.plainText
    }

    data class Strong(val children: List<InlineNode>) : InlineNode {
        override val plainText: String = children.plainText
    }

    data class Strikethrough(val children: List<InlineNode>) : InlineNode {
        override val plainText: String = children.plainText
    }

    data class InlineCode(val value: String) : InlineNode {
        override val plainText: String = value
    }

    data class Link(val destination: String, val title: String?, val children: List<InlineNode>) : InlineNode {
        override val plainText: String = children.plainText
    }

    data class Image(val source: String, val title: String?, val children: List<InlineNode>) : InlineNode {
        override val plainText: String = children.plainText
    }

    data object SoftBreak : InlineNode {
        override val plainText: String = " "
    }

    data object HardBreak : InlineNode {
        override val plainText: String = "\n"
    }

    data object LineBreak : InlineNode {
        override val plainText: String = "\n"
    }

    data class InlineHtml(val value: String) : InlineNode {
        override val plainText: String = value
    }

    data class Latex(val content: String) : InlineNode {
        override val plainText: String = content
    }

    data class Citation(val index: Int, val url: String?, val title: String?) : InlineNode {
        override val plainText: String = title ?: ""
    }

    data class CustomInline(val name: String, val content: String) : InlineNode {
        override val plainText: String = content
    }
}

val List<InlineNode>.plainText: String
    get() = joinToString(separator = "") { it.plainText }

internal fun BlockNode.typePrefix(): String =
    when (this) {
        is BlockNode.DocumentBlock -> "doc"
        is BlockNode.Heading -> "h${level}"
        is BlockNode.Paragraph -> "p"
        is BlockNode.CodeBlock -> "code"
        is BlockNode.BlockQuote -> "bq"
        is BlockNode.OrderedList -> "ol"
        is BlockNode.UnorderedList -> "ul"
        is BlockNode.Table -> "tbl"
        is BlockNode.ThematicBreak -> "hr"
        is BlockNode.HtmlBlock -> "html"
        is BlockNode.CustomBlock -> "custom"
        is BlockNode.LatexBlock -> "latex"
        is BlockNode.BlockDirective -> "dir"
    }
