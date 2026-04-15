package io.github.sigkitten.hairball.compose

import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

@Composable
internal fun EffectRenderedText(
    attributedString: AnnotatedString,
    revealedCount: Int,
    settledCount: Int,
    textStyle: TextStyle,
    textColor: Color,
    modifier: Modifier = Modifier,
    effect: StreamingTextEffect? = null,
    streamingTimeSeconds: Float = 0f,
    preserveExistingColors: Boolean = false,
) {
    var layoutResult by remember { mutableStateOf<TextLayoutResult?>(null) }
    val maskedText = remember(attributedString, settledCount, revealedCount, textColor, effect) {
        buildMaskedText(
            base = attributedString,
            settledCount = settledCount,
            revealedCount = revealedCount,
            hideAllGlyphs = effect != null,
        )
    }

    BasicText(
        text = maskedText,
        style = textStyle.copy(color = textColor),
        modifier = modifier.drawWithContent {
            drawContent()
            val layout = layoutResult ?: return@drawWithContent
            drawEffectOverlay(
                layout = layout,
                base = attributedString,
                revealedCount = revealedCount.coerceIn(0, attributedString.text.length),
                settledCount = settledCount.coerceIn(0, revealedCount.coerceIn(0, attributedString.text.length)),
                textStyle = textStyle,
                defaultColor = textColor,
                effect = effect,
                timeSeconds = streamingTimeSeconds.toDouble(),
                preserveExistingColors = preserveExistingColors,
            )
        },
        onTextLayout = { layoutResult = it },
    )
}

private fun buildMaskedText(
    base: AnnotatedString,
    settledCount: Int,
    revealedCount: Int,
    hideAllGlyphs: Boolean,
): AnnotatedString {
    val textLength = base.text.length
    if (textLength == 0) return base
    if (hideAllGlyphs) {
        return buildAnnotatedString {
            append(base)
            addStyle(
                SpanStyle(
                    color = Color.Transparent,
                    background = Color.Transparent,
                ),
                start = 0,
                end = textLength,
            )
        }
    }
    val hiddenStart = settledCount.coerceIn(0, textLength)
    if (hiddenStart >= textLength) return base

    return buildAnnotatedString {
        append(base)
        addStyle(
            SpanStyle(
                color = Color.Transparent,
                background = Color.Transparent,
            ),
            start = hiddenStart,
            end = textLength,
        )
        if (revealedCount < hiddenStart) {
            addStyle(SpanStyle(color = Color.Transparent), start = revealedCount, end = hiddenStart)
        }
    }
}

private data class GlyphSlice(
    val index: Int,
    val glyph: String,
    val rect: Rect,
    val center: Offset,
    val baseline: Float,
    val lineIndex: Int,
    val style: ResolvedGlyphStyle,
)

private data class ResolvedGlyphStyle(
    val color: Color,
    val background: Color,
    val fontSize: TextUnit,
    val fontWeight: FontWeight?,
    val fontStyle: FontStyle?,
    val fontFamily: FontFamily?,
    val textDecoration: TextDecoration?,
)

private fun DrawScope.drawEffectOverlay(
    layout: TextLayoutResult,
    base: AnnotatedString,
    revealedCount: Int,
    settledCount: Int,
    textStyle: TextStyle,
    defaultColor: Color,
    effect: StreamingTextEffect?,
    timeSeconds: Double,
    preserveExistingColors: Boolean,
) {
    if (effect == null || base.text.isEmpty() || revealedCount <= 0) {
        return
    }

    val slices = buildGlyphSlices(
        layout = layout,
        base = base,
        textStyle = textStyle,
        defaultColor = defaultColor,
        preserveExistingColors = preserveExistingColors,
    )
    val revealedSlices = slices.filter { it.index < revealedCount && it.glyph != "\n" }
    val activeSlices = slices.filter { it.index in settledCount until revealedCount && it.glyph != "\n" }
    val cursorSlice = slices.getOrNull(revealedCount - 1)?.takeIf { it.glyph != "\n" }
    if (revealedSlices.isEmpty() && effect !is MatrixDecodeEffect) {
        return
    }

    val context = EffectDrawContext(
        drawScope = this,
        base = base,
        layout = layout,
        slices = slices,
        revealedSlices = revealedSlices,
        activeSlices = activeSlices,
        revealedCount = revealedCount,
        settledCount = settledCount,
        defaultColor = defaultColor,
        cursorSlice = cursorSlice,
        timeSeconds = timeSeconds,
    )

    drawEffect(effect = effect, context = context, drawGlyphs = true)
}

private data class EffectDrawContext(
    val drawScope: DrawScope,
    val base: AnnotatedString,
    val layout: TextLayoutResult,
    val slices: List<GlyphSlice>,
    val revealedSlices: List<GlyphSlice>,
    val activeSlices: List<GlyphSlice>,
    val revealedCount: Int,
    val settledCount: Int,
    val defaultColor: Color,
    val cursorSlice: GlyphSlice?,
    val timeSeconds: Double,
)

private fun buildGlyphSlices(
    layout: TextLayoutResult,
    base: AnnotatedString,
    textStyle: TextStyle,
    defaultColor: Color,
    preserveExistingColors: Boolean,
): List<GlyphSlice> =
    base.text.indices.map { index ->
        val rect = layout.getBoundingBox(index)
        val lineIndex = layout.getLineForOffset(index)
        val style = resolveGlyphStyle(
            base = base,
            index = index,
            textStyle = textStyle,
            defaultColor = defaultColor,
            preserveExistingColors = preserveExistingColors,
        )
        GlyphSlice(
            index = index,
            glyph = base.text[index].toString(),
            rect = rect,
            center = Offset(rect.left + (rect.width / 2f), rect.top + (rect.height / 2f)),
            baseline = layout.getLineBaseline(lineIndex),
            lineIndex = lineIndex,
            style = style,
        )
    }

private fun resolveGlyphStyle(
    base: AnnotatedString,
    index: Int,
    textStyle: TextStyle,
    defaultColor: Color,
    preserveExistingColors: Boolean,
): ResolvedGlyphStyle {
    var merged = SpanStyle()
    base.spanStyles.forEach { range ->
        if (index in range.start until range.end) {
            merged = merged.merge(range.item)
        }
    }
    val resolvedColor = merged.color
        .takeUnless { it == Color.Unspecified }
        ?: defaultColor.takeUnless { it == Color.Unspecified }
        ?: Color.White

    return ResolvedGlyphStyle(
        color = if (preserveExistingColors) resolvedColor else resolvedColor,
        background = merged.background.takeUnless { it == Color.Unspecified } ?: Color.Transparent,
        fontSize = merged.fontSize.takeUnless { it.type == TextUnitType.Unspecified } ?: textStyle.fontSize,
        fontWeight = merged.fontWeight ?: textStyle.fontWeight,
        fontStyle = merged.fontStyle ?: textStyle.fontStyle,
        fontFamily = merged.fontFamily ?: textStyle.fontFamily,
        textDecoration = merged.textDecoration ?: textStyle.textDecoration,
    )
}

private fun drawEffect(
    effect: StreamingTextEffect?,
    context: EffectDrawContext,
    drawGlyphs: Boolean,
) {
    when (effect) {
        is CombinedEffect -> {
            val first = effect.effects.firstOrNull()
            if (first == null) {
                if (drawGlyphs) context.drawScope.drawNormalActiveGlyphs(context)
                return
            }
            drawEffect(first, context, drawGlyphs = true)
            effect.effects.drop(1).forEach { next ->
                drawEffect(next, context, drawGlyphs = false)
            }
        }
        is FadeEdgeEffect -> context.drawScope.drawFadeEdge(context, effect, drawGlyphs)
        is GlowCursorEffect -> context.drawScope.drawGlowCursor(context, effect, drawGlyphs)
        is WaveRevealEffect -> context.drawScope.drawWave(context, effect)
        is FireTrailEffect -> context.drawScope.drawFireTrail(context, effect)
        is SparkleEffect -> context.drawScope.drawSparkle(context, effect, drawGlyphs)
        is RainbowEffect -> context.drawScope.drawRainbow(context, effect)
        is ExplosionEffect -> context.drawScope.drawExplosion(context, effect)
        is NyanCatEffect -> context.drawScope.drawNyanCat(context, drawGlyphs)
        is MatrixDecodeEffect -> context.drawScope.drawMatrixDecode(context, effect)
        is PhosphorCrtEffect -> context.drawScope.drawPhosphor(context, effect)
        is ShockwaveEffect -> context.drawScope.drawShockwave(context, effect)
        null -> if (drawGlyphs) context.drawScope.drawNormalActiveGlyphs(context)
        else -> if (drawGlyphs) context.drawScope.drawNormalActiveGlyphs(context)
    }
}

private fun DrawScope.drawNormalActiveGlyphs(context: EffectDrawContext) {
    context.revealedSlices.forEach { glyph ->
        drawGlyph(glyph)
    }
}

private fun DrawScope.drawFadeEdge(context: EffectDrawContext, effect: FadeEdgeEffect, drawGlyphs: Boolean) {
    if (!drawGlyphs) return
    val trail = context.effectiveTrail(effect.edgeWidth)
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val alpha = if (dist <= trail) dist.toFloat() / trail.toFloat() else 1f
        drawGlyph(glyph, colorOverride = glyph.style.color.copy(alpha = alpha))
    }
}

private fun DrawScope.drawGlowCursor(context: EffectDrawContext, effect: GlowCursorEffect, drawGlyphs: Boolean) {
    if (drawGlyphs) {
        drawNormalActiveGlyphs(context)
    }
    val cursor = context.cursorSlice ?: return
    repeat(3) { ring ->
        val scale = 1f + ring * 0.45f
        drawCircle(
            color = Color(0xFF2FE4FF).copy(alpha = 0.18f / (ring + 1)),
            radius = effect.glowRadius * scale,
            center = Offset(cursor.rect.right, cursor.rect.top + cursor.rect.height / 2f),
        )
    }
}

private fun DrawScope.drawWave(context: EffectDrawContext, effect: WaveRevealEffect) {
    val trail = context.effectiveTrail(effect.wavelength)
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val yOffset = if (dist <= trail) {
            sin((dist.toDouble() / trail.toDouble()) * PI).toFloat() * effect.amplitude
        } else {
            0f
        }
        drawGlyph(glyph, translateY = yOffset)
    }
}

private fun DrawScope.drawFireTrail(context: EffectDrawContext, effect: FireTrailEffect) {
    val trail = context.effectiveTrail(effect.trailLength)
    val trailPoints = mutableListOf<Pair<Offset, Double>>()
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val t = dist.toDouble() / trail.toDouble()
        val warmth = max(0.0, 1.0 - t)
        drawGlyph(
            glyph,
            colorOverride = Color(
                red = 1f,
                green = (0.5 + warmth * 0.5).toFloat(),
                blue = (warmth * 0.3).toFloat(),
                alpha = glyph.style.color.alpha,
            ),
        )
        trailPoints += glyph.center to t
    }
    trailPoints.forEach { (point, t) ->
        val size = ((1.0 - t) * 8.0).toFloat()
        val opacity = ((1.0 - t) * 0.35).toFloat()
        val yJitter = (sin(t * effect.trailLength * 1.5) * 3.0).toFloat()
        drawCircle(
            color = Color(0xFFFF6A00).copy(alpha = opacity),
            radius = size / 2f,
            center = Offset(point.x, point.y - 4f + yJitter),
        )
        drawCircle(
            color = Color(0xFFFFD166).copy(alpha = opacity * 0.6f),
            radius = size / 3f,
            center = Offset(point.x, point.y - 5f + yJitter),
        )
    }
}

private fun DrawScope.drawSparkle(context: EffectDrawContext, effect: SparkleEffect, drawGlyphs: Boolean) {
    if (drawGlyphs) {
        drawNormalActiveGlyphs(context)
    }
    val cursor = context.cursorSlice ?: return
    val center = Offset(cursor.rect.right, cursor.rect.top + cursor.rect.height / 2f)
    repeat(effect.sparkleCount) { i ->
        val angle = (i.toDouble() / effect.sparkleCount.toDouble()) * PI * 2.0
        val seed = ((context.revealedCount * 7 + i * 13) % 100) / 100.0
        val dist = 4.0 + seed * 12.0
        drawCircle(
            color = Color.Yellow.copy(alpha = (1.0 - seed * 0.6).toFloat()),
            radius = (1.5 + seed * 2.5).toFloat(),
            center = Offset(
                x = center.x + (cos(angle + seed * 2.0) * dist).toFloat(),
                y = center.y + (sin(angle + seed * 2.0) * dist).toFloat(),
            ),
        )
    }
}

private fun DrawScope.drawRainbow(context: EffectDrawContext, effect: RainbowEffect) {
    val trail = context.effectiveTrail(effect.trailLength)
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val color = if (dist <= trail) {
            rainbowEffectColor(glyph.index, context.timeSeconds.toFloat())
        } else {
            glyph.style.color
        }
        drawGlyph(glyph, colorOverride = color)
    }
}

private fun DrawScope.drawExplosion(context: EffectDrawContext, effect: ExplosionEffect) {
    val trail = context.effectiveTrail(effect.trailWidth)
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val t = dist.toDouble() / trail.toDouble()
        val shake = ((1.0 - t) * 2.0).toFloat()
        val shakeX = (sin(glyph.index * 7.0) * shake.toDouble()).toFloat()
        val shakeY = (cos(glyph.index * 11.0) * shake.toDouble()).toFloat()
        drawGlyph(
            glyph,
            translateX = shakeX,
            translateY = shakeY,
            colorOverride = if (dist <= 2) Color.White else glyph.style.color,
        )

        repeat(effect.particleCount) { i ->
            val angle = (i.toDouble() / effect.particleCount.toDouble()) * PI * 2.0
            val jitter = ((glyph.index * 13 + i * 7) % 100) / 100.0
            val radius = (t * effect.burstRadius * (0.6 + jitter * 0.4)).toFloat()
            val px = glyph.center.x + (cos(angle + jitter) * radius).toFloat()
            val py = glyph.center.y + (sin(angle + jitter) * radius).toFloat()
            val size = ((1.0 - t) * 3.0 + 0.5).toFloat()
            drawCircle(
                color = rainbowEffectColor(glyph.index + i, context.timeSeconds.toFloat()).copy(alpha = max(0.0, 1.0 - t * 1.2).toFloat()),
                radius = size / 2f,
                center = Offset(px, py),
            )
        }
    }
}

private fun DrawScope.drawNyanCat(context: EffectDrawContext, drawGlyphs: Boolean) {
    if (drawGlyphs) {
        drawNormalActiveGlyphs(context)
    }
    val cursor = context.cursorSlice ?: return
    val px = 2f
    val catX = cursor.rect.right + 4f
    val bounce = (sin(context.revealedCount * 0.5) * 2.0).toFloat()
    val catY = cursor.rect.top - 6f + bounce
    val rainbowColors = listOf(
        Color(0xFFFF0000),
        Color(0xFFFF9900),
        Color(0xFFFFFF00),
        Color(0xFF00CC00),
        Color(0xFF0099FF),
        Color(0xFF9966FF),
    )

    rainbowColors.forEachIndexed { index, color ->
        drawRect(
            color = color.copy(alpha = 0.9f),
            topLeft = Offset(catX - 30f, catY + ((index + 1) * px * 1.2f) - 2f),
            size = Size(30f, px * 1.2f),
        )
    }

    drawRoundRect(
        color = Color(0xFFD9BF8C),
        topLeft = Offset(catX - px, catY),
        size = Size(px * 6f, px * 5f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(2f, 2f),
    )
    drawRoundRect(
        color = Color(0xFFFF99B3),
        topLeft = Offset(catX - px + px * 0.5f, catY + px * 0.5f),
        size = Size(px * 5f, px * 3.5f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(1f, 1f),
    )
    drawRoundRect(
        color = Color(0xFF999999),
        topLeft = Offset(catX + px * 5f, catY - px * 0.5f),
        size = Size(px * 4f, px * 4f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(1.5f, 1.5f),
    )
}

private fun DrawScope.drawMatrixDecode(context: EffectDrawContext, effect: MatrixDecodeEffect) {
    val slices = context.slices
    val visibleSlices = slices.filter { it.glyph != "\n" }
    if (visibleSlices.isEmpty()) return
    val minY = visibleSlices.minOf { it.rect.top }
    val maxY = visibleSlices.maxOf { it.rect.bottom }
    val totalHeight = max(maxY - minY, 1f)
    val frame = if (context.timeSeconds > 0) (context.timeSeconds * 60.0).toInt() else context.revealedCount

    visibleSlices.forEach { glyph ->
        when {
            glyph.index < context.settledCount -> {
                drawGlyph(glyph)
            }
            glyph.index < context.revealedCount -> {
                val colHash = abs((glyph.rect.left * 7.3f + 100f).toInt()) + 1
                val age = context.revealedCount - glyph.index
                val decodeDelay = 3 + (colHash % 5)
                val decoded = age > decodeDelay
                val yNorm = (glyph.rect.top - minY) / totalHeight
                val rainTime = if (context.timeSeconds > 0) context.timeSeconds else context.revealedCount / 60.0
                val rainSpeed = 0.5 + (colHash % 7) * 0.3
                val rainOffset = (colHash % 13) / 13.0
                val rainPos = ((rainTime * rainSpeed + rainOffset) % 1.6) - 0.3
                val distFromHead = yNorm - rainPos
                val streakLen = 0.15 + (colHash % 5) * 0.04
                val isHead = distFromHead >= -0.02 && distFromHead <= 0.02
                val brightness = when {
                    isHead -> 1.0
                    distFromHead < -0.02 && distFromHead >= -streakLen -> {
                        val t = abs(distFromHead) / streakLen
                        max(0.3, 0.9 * (1.0 - t))
                    }
                    else -> if (((frame * 3 + glyph.index * 7) % 10) < 2) 0.35 else 0.15
                }

                if (decoded) {
                    val rainGlow = if (isHead) 0.6 else max(brightness * 0.3, 0.05)
                    drawGlyph(glyph, colorOverride = Color(0xFF00E65C).copy(alpha = rainGlow.toFloat()))
                } else {
                    val speed = 2 + (colHash % 4)
                    val glyphFrame = (frame + colHash * 31) / speed
                    val seed = ((glyphFrame * 17 + glyph.index * 13) % MATRIX_CHARS.length + MATRIX_CHARS.length) % MATRIX_CHARS.length
                    drawGlyphString(
                        glyph = MATRIX_CHARS[seed].toString(),
                        template = glyph,
                        color = if (isHead) Color(0xFFB3FFB3).copy(alpha = brightness.toFloat()) else Color(0xFF00E65C).copy(alpha = brightness.toFloat()),
                        forceMonospace = true,
                    )
                }
            }
            else -> {
                val lookAhead = glyph.index - context.revealedCount
                if (lookAhead < effect.trailLength * 3) {
                    val seed = ((frame * 7 + glyph.index * 13) % MATRIX_CHARS.length + MATRIX_CHARS.length) % MATRIX_CHARS.length
                    val opacity = max(0.0, 1.0 - lookAhead.toDouble() / (effect.trailLength * 3).toDouble()) * 0.2
                    drawGlyphString(
                        glyph = MATRIX_CHARS[seed].toString(),
                        template = glyph,
                        color = Color(0xFF00E65C).copy(alpha = opacity.toFloat()),
                        forceMonospace = true,
                    )
                }
            }
        }
    }
}

private fun DrawScope.drawPhosphor(context: EffectDrawContext, effect: PhosphorCrtEffect) {
    val trail = context.effectiveTrail(effect.decayLength)
    val bounds = mutableListOf<Rect>()
    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val t = dist.toDouble() / trail.toDouble()
        val red = max(0.0, 1.0 - t * 3.0)
        val green = max(0.2, 1.0 - t * 0.6)
        val blue = max(0.0, 0.8 - t * 2.0)
        drawGlyph(
            glyph,
            colorOverride = Color(
                red = red.toFloat(),
                green = green.toFloat(),
                blue = blue.toFloat(),
                alpha = glyph.style.color.alpha,
            ),
        )
        if (dist <= 5) {
            drawGlyph(
                glyph,
                colorOverride = Color(0xFF80FF80).copy(alpha = ((1.0 - dist.toDouble() / 5.0) * 0.35).toFloat()),
                scale = 1.03f,
            )
        }
        bounds += glyph.rect
    }
    if (bounds.isEmpty()) return
    val minX = bounds.minOf { it.left }
    val maxX = bounds.maxOf { it.right }
    val minY = bounds.minOf { it.top }
    val maxY = bounds.maxOf { it.bottom }
    var y = minY
    while (y < maxY) {
        drawRect(
            color = Color.Black.copy(alpha = 0.12f),
            topLeft = Offset(minX, y),
            size = Size(maxX - minX, 1f),
        )
        y += 3f
    }
}

private fun DrawScope.drawShockwave(context: EffectDrawContext, effect: ShockwaveEffect) {
    val trail = context.effectiveTrail(effect.trailWidth)
    val cursor = context.cursorSlice ?: return
    val epicenter = Offset(cursor.rect.right, cursor.rect.top + cursor.rect.height / 2f)

    context.revealedSlices.forEach { glyph ->
        val dist = context.revealedCount - glyph.index
        val dx = glyph.center.x - epicenter.x
        val dy = glyph.center.y - epicenter.y
        val distance = sqrt(dx * dx + dy * dy)
        var offsetX = 0f
        var offsetY = 0f
        if (dist <= trail && distance < effect.waveRadius && distance > 0f) {
            val t = dist.toDouble() / trail.toDouble()
            val waveFade = max(0.0, 1.0 - t)
            val distFade = max(0.0, 1.0 - distance / effect.waveRadius)
            val strength = waveFade * distFade * effect.displacement
            offsetX = (dx / distance) * strength.toFloat()
            offsetY = (dy / distance) * strength.toFloat()
        }
        drawGlyph(
            glyph,
            translateX = offsetX,
            translateY = offsetY,
            colorOverride = if (dist <= 3) Color.White else glyph.style.color,
        )
    }

    for (waveAge in 0 until min(trail, context.revealedCount)) {
        val t = waveAge.toDouble() / trail.toDouble()
        val ringRadius = (t * effect.waveRadius).toFloat()
        if (ringRadius <= 2f) continue
        drawCircle(
            color = Color.White.copy(alpha = ((1.0 - t) * 0.15).toFloat()),
            radius = ringRadius,
            center = epicenter,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.5f),
        )
    }
}

private fun DrawScope.drawGlyph(
    glyph: GlyphSlice,
    colorOverride: Color? = null,
    translateX: Float = 0f,
    translateY: Float = 0f,
    scale: Float = 1f,
) {
    drawGlyphString(
        glyph = glyph.glyph,
        template = glyph,
        color = colorOverride ?: glyph.style.color,
        translateX = translateX,
        translateY = translateY,
        scale = scale,
        forceMonospace = false,
    )
}

private fun DrawScope.drawGlyphString(
    glyph: String,
    template: GlyphSlice,
    color: Color,
    translateX: Float = 0f,
    translateY: Float = 0f,
    scale: Float = 1f,
    forceMonospace: Boolean = false,
) {
    if (glyph == "\n") return

    if (template.style.background.alpha > 0f) {
        drawRect(
            color = template.style.background,
            topLeft = Offset(template.rect.left + translateX, template.rect.top + translateY),
            size = Size(template.rect.width, template.rect.height),
        )
    }

    drawIntoCanvas { canvas ->
        val paint = createTextPaint(
            style = template.style,
            color = color,
            density = density,
            forceMonospace = forceMonospace,
        )
        val nativeCanvas = canvas.nativeCanvas
        nativeCanvas.save()
        nativeCanvas.translate(translateX, translateY)
        if (scale != 1f) {
            nativeCanvas.scale(scale, scale, template.center.x, template.baseline)
        }
        nativeCanvas.drawText(glyph, template.rect.left, template.baseline, paint)
        nativeCanvas.restore()
    }

    if (template.style.textDecoration?.contains(TextDecoration.Underline) == true) {
        drawLine(
            color = color,
            start = Offset(template.rect.left + translateX, template.rect.bottom + translateY - 2f),
            end = Offset(template.rect.right + translateX, template.rect.bottom + translateY - 2f),
            strokeWidth = 1f,
        )
    }
    if (template.style.textDecoration?.contains(TextDecoration.LineThrough) == true) {
        val y = template.rect.top + (template.rect.height / 2f) + translateY
        drawLine(
            color = color,
            start = Offset(template.rect.left + translateX, y),
            end = Offset(template.rect.right + translateX, y),
            strokeWidth = 1f,
        )
    }
}

private fun createTextPaint(
    style: ResolvedGlyphStyle,
    color: Color,
    density: Float,
    forceMonospace: Boolean,
): TextPaint =
    TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color.toArgb()
        textSize = style.fontSize.toPx(density)
        typeface = selectTypeface(
            family = if (forceMonospace) FontFamily.Monospace else style.fontFamily,
            fontWeight = style.fontWeight,
            fontStyle = style.fontStyle,
        )
    }

private fun TextUnit.toPx(density: Float): Float =
    when (type) {
        TextUnitType.Sp -> value * density
        TextUnitType.Em -> value * 16f * density
        else -> 16f * density
    }

private fun selectTypeface(
    family: FontFamily?,
    fontWeight: FontWeight?,
    fontStyle: FontStyle?,
): Typeface {
    val base = when (family) {
        FontFamily.Monospace -> Typeface.MONOSPACE
        FontFamily.Serif -> Typeface.SERIF
        else -> Typeface.SANS_SERIF
    }
    val style = when {
        (fontWeight?.weight ?: FontWeight.Normal.weight) >= FontWeight.SemiBold.weight && fontStyle == FontStyle.Italic -> Typeface.BOLD_ITALIC
        (fontWeight?.weight ?: FontWeight.Normal.weight) >= FontWeight.SemiBold.weight -> Typeface.BOLD
        fontStyle == FontStyle.Italic -> Typeface.ITALIC
        else -> Typeface.NORMAL
    }
    return Typeface.create(base, style)
}

private fun EffectDrawContext.effectiveTrail(ownTrail: Int): Int =
    max(ownTrail, revealedCount - settledCount)

private fun rainbowEffectColor(index: Int, timeSeconds: Float): Color {
    val palette = listOf(
        Color(0xFFFF5F6D),
        Color(0xFFFFC371),
        Color(0xFF47D16C),
        Color(0xFF4FC3F7),
        Color(0xFF7C4DFF),
    )
    val offset = ((timeSeconds * 8f).toInt() + index) % palette.size
    return palette[offset]
}

private val MATRIX_CHARS = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789$#@&%!?<>{}[]+="
