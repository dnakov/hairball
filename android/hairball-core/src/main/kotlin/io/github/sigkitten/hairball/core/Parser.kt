package io.github.sigkitten.hairball.core

import com.vladsch.flexmark.ast.BlockQuote
import com.vladsch.flexmark.ast.BulletList
import com.vladsch.flexmark.ast.Code
import com.vladsch.flexmark.ast.Emphasis
import com.vladsch.flexmark.ast.FencedCodeBlock
import com.vladsch.flexmark.ast.HardLineBreak
import com.vladsch.flexmark.ast.Heading
import com.vladsch.flexmark.ast.HtmlBlock
import com.vladsch.flexmark.ast.HtmlInline
import com.vladsch.flexmark.ast.Image
import com.vladsch.flexmark.ast.IndentedCodeBlock
import com.vladsch.flexmark.ast.Link
import com.vladsch.flexmark.ast.OrderedList
import com.vladsch.flexmark.ast.Paragraph
import com.vladsch.flexmark.ast.SoftLineBreak
import com.vladsch.flexmark.ast.StrongEmphasis
import com.vladsch.flexmark.ast.Text
import com.vladsch.flexmark.ast.ThematicBreak
import com.vladsch.flexmark.ext.autolink.AutolinkExtension
import com.vladsch.flexmark.ext.gfm.strikethrough.Strikethrough
import com.vladsch.flexmark.ext.gfm.strikethrough.StrikethroughSubscriptExtension
import com.vladsch.flexmark.ext.gfm.tasklist.TaskListExtension
import com.vladsch.flexmark.ext.gfm.tasklist.TaskListItem
import com.vladsch.flexmark.ext.tables.TableBlock
import com.vladsch.flexmark.ext.tables.TableCell
import com.vladsch.flexmark.ext.tables.TableHead
import com.vladsch.flexmark.ext.tables.TableRow
import com.vladsch.flexmark.ext.tables.TablesExtension
import com.vladsch.flexmark.parser.Parser
import com.vladsch.flexmark.util.ast.Node
import com.vladsch.flexmark.util.data.MutableDataSet

enum class ParseOption {
    ParseBlockDirectives,
    ParseSymbolLinks,
    ParseMinimalDoxygen,
}

class MarkdownParser(
    private val options: Set<ParseOption> = setOf(ParseOption.ParseBlockDirectives),
) {
    private val parser: Parser = Parser.builder(
        MutableDataSet().set(
            Parser.EXTENSIONS,
            listOf(
                TablesExtension.create(),
                TaskListExtension.create(),
                StrikethroughSubscriptExtension.create(),
                AutolinkExtension.create(),
            ),
        ),
    ).build()

    fun parse(markdown: String): Document {
        val node = parser.parse(markdown)
        var blocks = convertBlocks(node).map(::applyDirectiveConversion)
        if (blocks.none { it is BlockNode.Table }) {
            blocks = applyTopLevelTableFallback(markdown, blocks)
        }
        return Document(blocks = blocks)
    }

    private fun convertBlocks(parent: Node): List<BlockNode> =
        parent.children().mapNotNull(::convertBlock)

    private fun convertInlines(parent: Node): List<InlineNode> =
        parent.children().mapNotNull(::convertInline)

    private fun convertBlock(node: Node): BlockNode? =
        when (node) {
            is com.vladsch.flexmark.util.ast.Document -> BlockNode.DocumentBlock(convertBlocks(node))
            is Heading -> BlockNode.Heading(node.level, convertInlines(node))
            is Paragraph -> BlockNode.Paragraph(convertInlines(node))
            is FencedCodeBlock -> BlockNode.CodeBlock(node.info.toString().ifBlank { null }, node.contentChars.normalizeEol())
            is IndentedCodeBlock -> BlockNode.CodeBlock(null, node.contentChars.normalizeEol())
            is BlockQuote -> BlockNode.BlockQuote(convertBlocks(node))
            is OrderedList -> BlockNode.OrderedList(node.startNumber, isTightList(node), node.children().mapNotNull(::convertListItem))
            is BulletList -> BlockNode.UnorderedList(isTightList(node), node.children().mapNotNull(::convertListItem))
            is TableBlock -> {
                val head = node.firstChild as? TableHead
                val bodyRows = node.children()
                    .filterIsInstance<TableRow>()
                    .drop(if (head != null) 1 else 0)
                BlockNode.Table(
                    columnAlignments = convertAlignments(head),
                    head = convertTableRow(head?.firstChild as? TableRow),
                    body = bodyRows.map(::convertTableRow),
                )
            }
            is ThematicBreak -> BlockNode.ThematicBreak
            is HtmlBlock -> BlockNode.HtmlBlock(node.chars.toString())
            else -> null
        }

    private fun convertInline(node: Node): InlineNode? =
        when (node) {
            is Text -> InlineNode.Text(node.chars.toString())
            is Emphasis -> InlineNode.Emphasis(convertInlines(node))
            is StrongEmphasis -> InlineNode.Strong(convertInlines(node))
            is Strikethrough -> InlineNode.Strikethrough(convertInlines(node))
            is Code -> InlineNode.InlineCode(node.text.toString())
            is Link -> InlineNode.Link(node.url.toString(), node.title.toString().ifBlank { null }, convertInlines(node))
            is Image -> InlineNode.Image(node.url.toString(), node.title.toString().ifBlank { null }, convertInlines(node))
            is SoftLineBreak -> InlineNode.SoftBreak
            is HardLineBreak -> InlineNode.HardBreak
            is HtmlInline -> InlineNode.InlineHtml(node.chars.toString())
            else -> null
        }

    private fun convertListItem(node: Node): ListItem? {
        val item = node as? com.vladsch.flexmark.ast.ListItem ?: return null
        val checkbox = if (item is TaskListItem) {
            if (item.isItemDoneMarker) CheckboxState.Checked else CheckboxState.Unchecked
        } else {
            null
        }
        return ListItem(children = convertBlocks(item), checkbox = checkbox)
    }

    private fun convertTableRow(row: TableRow?): MarkdownTableRow =
        MarkdownTableRow(
            cells = row?.children()
                ?.filterIsInstance<TableCell>()
                ?.map { cell -> MarkdownTableCell(convertInlines(cell)) }
                ?: emptyList(),
        )

    private fun convertAlignments(head: TableHead?): List<MarkdownTableColumnAlignment> {
        val row = head?.firstChild as? TableRow ?: return emptyList()
        return row.children()
            .filterIsInstance<TableCell>()
            .map { cell ->
                when (cell.alignment?.name?.lowercase()) {
                    "left" -> MarkdownTableColumnAlignment.Left
                    "center" -> MarkdownTableColumnAlignment.Center
                    "right" -> MarkdownTableColumnAlignment.Right
                    else -> MarkdownTableColumnAlignment.None
                }
            }
    }

    private fun isTightList(list: Node): Boolean =
        list.children()
            .filterIsInstance<com.vladsch.flexmark.ast.ListItem>()
            .all { item -> item.children().size <= 1 }

    private fun applyDirectiveConversion(block: BlockNode): BlockNode =
        if (!options.contains(ParseOption.ParseBlockDirectives)) {
            block
        } else {
            when (block) {
                is BlockNode.Paragraph -> convertParagraphDirective(block) ?: block
                else -> block
            }
        }

    private fun applyTopLevelTableFallback(markdown: String, parsedBlocks: List<BlockNode>): List<BlockNode> {
        val lines = markdown.lines()
        val start = lines.indices.firstOrNull { index ->
            index + 1 < lines.size && looksLikeTableRow(lines[index]) && looksLikeTableSeparator(lines[index + 1])
        } ?: return parsedBlocks

        val end = (start + 2 until lines.size)
            .takeWhile { index -> lines[index].isNotBlank() && looksLikeTableRow(lines[index]) }
            .lastOrNull() ?: (start + 1)

        val prefix = lines.take(start).joinToString("\n").trimEnd()
        val suffix = lines.drop(end + 1).joinToString("\n").trimStart()
        val headCells = parseTableLine(lines[start])
        val bodyRows = if (end > start + 1) lines.subList(start + 2, end + 1).map(::parseTableLine) else emptyList()

        val prefixBlocks = if (prefix.isBlank()) emptyList() else parse(prefix).blocks
        val suffixBlocks = if (suffix.isBlank()) emptyList() else parse(suffix).blocks
        val table = BlockNode.Table(
            columnAlignments = parseAlignments(lines[start + 1], headCells.size),
            head = MarkdownTableRow(headCells.map { MarkdownTableCell(listOf(InlineNode.Text(it))) }),
            body = bodyRows.map { row -> MarkdownTableRow(row.map { MarkdownTableCell(listOf(InlineNode.Text(it))) }) },
        )

        return prefixBlocks + table + suffixBlocks
    }

    private fun looksLikeTableRow(line: String): Boolean =
        line.trim().let { trimmed -> trimmed.contains('|') && trimmed.count { it == '|' } >= 2 }

    private fun looksLikeTableSeparator(line: String): Boolean =
        Regex("""^\s*\|?[:\- ]+\|[:\-| ]+\|?\s*$""").matches(line)

    private fun parseTableLine(line: String): List<String> =
        line.trim()
            .removePrefix("|")
            .removeSuffix("|")
            .split("|")
            .map { it.trim() }

    private fun parseAlignments(line: String, count: Int): List<MarkdownTableColumnAlignment> =
        parseTableLine(line).map { cell ->
            when {
                cell.startsWith(":") && cell.endsWith(":") -> MarkdownTableColumnAlignment.Center
                cell.endsWith(":") -> MarkdownTableColumnAlignment.Right
                cell.startsWith(":") -> MarkdownTableColumnAlignment.Left
                else -> MarkdownTableColumnAlignment.None
            }
        }.let { alignments ->
            if (alignments.size >= count) alignments else alignments + List(count - alignments.size) { MarkdownTableColumnAlignment.None }
        }

    private fun convertParagraphDirective(paragraph: BlockNode.Paragraph): BlockNode.BlockDirective? {
        if (paragraph.content.any { inline ->
                inline !is InlineNode.Text &&
                    inline !is InlineNode.SoftBreak &&
                    inline !is InlineNode.HardBreak &&
                    inline !is InlineNode.LineBreak
            }) {
            return null
        }

        val fullText = paragraph.content.joinToString(separator = "") { inline ->
            when (inline) {
                is InlineNode.Text -> inline.value
                is InlineNode.SoftBreak, is InlineNode.HardBreak, is InlineNode.LineBreak -> "\n"
                else -> ""
            }
        }
        val lines = fullText.lines()
        val first = lines.firstOrNull()?.trim() ?: return null
        val last = lines.lastOrNull()?.trim() ?: return null
        if (!first.startsWith("@") || !first.endsWith("{") || last != "}") return null

        val name = first.removePrefix("@").removeSuffix("{").trim()
        if (name.isEmpty()) return null

        val body = lines.drop(1).dropLast(1).joinToString("\n").trim('\n')
        val children = if (body.isBlank()) emptyList() else listOf(BlockNode.Paragraph(listOf(InlineNode.Text(body))))
        return BlockNode.BlockDirective(name = name, arguments = null, children = children)
    }

    private fun Node.children(): List<Node> =
        generateSequence(firstChild) { it.next }.toList()

    private fun com.vladsch.flexmark.util.sequence.BasedSequence.normalizeEol(): String =
        toString().replace("\r\n", "\n")
}
