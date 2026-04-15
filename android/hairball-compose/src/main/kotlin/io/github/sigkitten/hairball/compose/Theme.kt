package io.github.sigkitten.hairball.compose

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Immutable
data class HeadingStyle(
    val textStyle: TextStyle,
    val topSpacingDp: Int,
    val bottomSpacingDp: Int,
    val color: Color,
)

@Immutable
data class HeadingStyleSet(
    val h1: HeadingStyle = HeadingStyle(TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold), 0, 16, Color.Unspecified),
    val h2: HeadingStyle = HeadingStyle(TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold), 24, 12, Color.Unspecified),
    val h3: HeadingStyle = HeadingStyle(TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold), 20, 8, Color.Unspecified),
    val h4: HeadingStyle = HeadingStyle(TextStyle(fontSize = 14.sp, fontWeight = FontWeight.SemiBold), 16, 6, Color.Unspecified),
    val h5: HeadingStyle = HeadingStyle(TextStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold), 12, 4, Color.Unspecified),
    val h6: HeadingStyle = HeadingStyle(TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold), 12, 4, Color.Unspecified),
) {
    operator fun get(level: Int): HeadingStyle = when (level) {
        1 -> h1
        2 -> h2
        3 -> h3
        4 -> h4
        5 -> h5
        else -> h6
    }
}

@Immutable
data class CodeBlockStyle(
    val backgroundColor: Color = Color(0xFFF5F5F5),
    val textColor: Color = Color.Unspecified,
    val textStyle: TextStyle = TextStyle(fontSize = 12.sp),
    val cornerRadiusDp: Int = 4,
    val horizontalPaddingDp: Int = 12,
    val verticalPaddingDp: Int = 12,
    val showLanguageLabel: Boolean = true,
    val showCopyButton: Boolean = true,
)

@Immutable
data class InlineCodeStyle(
    val backgroundColor: Color = Color(0xFFF0F0F0),
    val textColor: Color = Color.Unspecified,
    val spanStyle: SpanStyle = SpanStyle(fontSize = 12.sp),
)

@Immutable
data class BlockquoteStyle(
    val borderColor: Color = Color(0xFF4A90E2),
    val borderWidthDp: Int = 3,
    val backgroundColor: Color = Color.Transparent,
    val textColor: Color = Color.Gray,
)

enum class TableBackgroundStyle {
    None,
    Solid,
    Alternating,
}

@Immutable
data class TableStyle(
    val headerBackground: Color = Color(0xFFF5F5F5),
    val borderColor: Color = Color(0xFFDDDDDD),
    val borderWidthDp: Int = 1,
    val backgroundStyle: TableBackgroundStyle = TableBackgroundStyle.Alternating,
)

enum class UnorderedListMarker(val marker: String) {
    Bullet("\u2022"),
    Dash("-"),
}

@Immutable
data class ListStyleConfiguration(
    val bulletMarker: UnorderedListMarker = UnorderedListMarker.Bullet,
    val indentWidthDp: Int = 24,
    val itemSpacingDp: Int = 4,
    val tightItemSpacingDp: Int = 2,
    val checkboxCheckedSymbol: String = "[x]",
    val checkboxUncheckedSymbol: String = "[ ]",
)

@Immutable
data class LinkStyle(
    val color: Color = Color(0xFF2563EB),
    val underline: Boolean = true,
)

@Immutable
data class CitationStyle(
    val textColor: Color = Color(0xFF666666),
    val backgroundColor: Color = Color(0xFFF5F5F5),
)

enum class SoftBreakMode {
    Space,
    LineBreak,
}

@Immutable
data class MarkdownTheme(
    val bodyTextStyle: TextStyle = TextStyle(fontSize = 14.sp),
    val foregroundColor: Color = Color.Unspecified,
    val lineSpacing: Float = 1.6f,
    val paragraphSpacingDp: Int = 12,
    val headingStyleSet: HeadingStyleSet = HeadingStyleSet(),
    val codeBlock: CodeBlockStyle = CodeBlockStyle(),
    val inlineCode: InlineCodeStyle = InlineCodeStyle(),
    val blockquote: BlockquoteStyle = BlockquoteStyle(),
    val table: TableStyle = TableStyle(),
    val list: ListStyleConfiguration = ListStyleConfiguration(),
    val link: LinkStyle = LinkStyle(),
    val citation: CitationStyle = CitationStyle(),
    val softBreakMode: SoftBreakMode = SoftBreakMode.Space,
) {
    companion object {
        val Default = MarkdownTheme()
        val AssistantBubble = MarkdownTheme(
            bodyTextStyle = TextStyle(fontSize = 15.sp),
            foregroundColor = Color(0xFF1A1A1A),
            paragraphSpacingDp = 10,
        )
        val UserBubble = MarkdownTheme(
            bodyTextStyle = TextStyle(fontSize = 15.sp),
            foregroundColor = Color.White,
            codeBlock = CodeBlockStyle(backgroundColor = Color.White.copy(alpha = 0.15f)),
            inlineCode = InlineCodeStyle(backgroundColor = Color.White.copy(alpha = 0.15f)),
            link = LinkStyle(color = Color.White),
        )
    }
}
