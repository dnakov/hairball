# Hairball

A Swift markdown parsing and rendering library for iOS and macOS. Two targets:

- **Hairball** — parsing, AST, processors. No UI dependencies.
- **HairballUI** — SwiftUI rendering with theming, syntax highlighting (Highlightr), LaTeX (SwiftMath), streaming support, and per-glyph text effects via iOS 18's `TextRenderer`.

```swift
.package(url: "https://github.com/dnakov/hairball.git", from: "1.0.0")
```

Platforms: iOS 18+, macOS 15+

## Monorepo Layout

- `Sources/` and `Tests/` keep the root SwiftPM package surface for Apple consumers.
- `apps/apple-demo/` contains the Apple demo app and Xcode project assets.
- `android/` contains the Android Gradle workspace:
  `hairball-core`, `hairball-compose`, and `hairball-demo`.
- `spec/fixtures/` contains Swift-generated golden fixtures used to keep Android aligned with the Swift AST and processor behavior.
- `scripts/` contains cross-platform verification helpers:
  `export-fixtures.sh`, `verify-fixtures.sh`, `build-apple-demo.sh`, and `android-publish-dry-run.sh`.

---

## Quick Start

```swift
import HairballUI

// Render a markdown string
MarkdownView("# Hello\n\nSome **bold** and *italic* text.")

// With processors
MarkdownView("Check $E=mc^2$ and https://example.com", processors: [
    LatexTransformer(),
    AutoLinkTransformer(),
    CitationProcessor(),
])

// With a theme
MarkdownView("# Styled")
    .markdownTheme(.assistantBubble)

// With syntax highlighting theme
MarkdownView("```swift\nlet x = 42\n```")
    .codeSyntaxHighlighter(HighlightrCodeSyntaxHighlighter(theme: "github-dark"))
```

---

## Rendering Layers

Four layers, from highest to lowest level of control:

### Layer 1: `MarkdownView` — highest level

Takes a string, parses it, renders it.

```swift
MarkdownView("# Title\n\nParagraph with **bold**.")
```

### Layer 2: `MarkdownDocumentView` — you own the document

You parse the markdown yourself. The view just renders.

```swift
let parser = MarkdownParser()
let doc = parser.parse(myMarkdown)

MarkdownDocumentView(document: doc)
```

### Layer 3: `MarkdownBlocksView` — you own the blocks and animation

You parse, identify blocks, and control streaming animation.

```swift
let blocks = IdentifiedBlock.identify(document.blocks)

MarkdownBlocksView(blocks: blocks, isStreaming: true)
    .streamingTextEffect(FadeEdgeEffect(edgeWidth: 8))
    .tokenReveal(.init(duration: 0.15, mode: .continuous))
```

### Layer 4: `BlockNodeView` — you own everything

Render individual blocks with zero opinions from the library.

```swift
ForEach(IdentifiedBlock.identify(doc.blocks)) { item in
    BlockNodeView(node: item.block)
}
```

---

## Streaming

### Option A: Let Hairball manage the pipeline

```swift
@StateObject var renderer = StreamingMarkdownRenderer(
    processors: [LatexTransformer(), AutoLinkTransformer()],
    throttleInterval: 0.016
)

// View
StreamingMarkdownContentView(renderer: renderer)
    .streamingTextEffect(FadeEdgeEffect())
    .tokenReveal(.init(duration: 0.15, mode: .continuous))

// Feed tokens
Task {
    for await token in myLLMStream {
        renderer.append(token)
    }
    renderer.finish()
}
```

### Option B: You handle streaming, Hairball renders

```swift
@State private var document = Document(blocks: [])
let parser = MarkdownParser()

MarkdownDocumentView(document: document, isStreaming: true)
    .streamingTextEffect(MatrixDecodeEffect())
    .tokenReveal(.default)

func onToken(_ token: String) {
    accumulated += token
    document = parser.parse(accumulated)
}
```

### Reveal Config — timing and mode

```swift
.tokenReveal(TokenRevealConfig(
    duration: 0.15,       // smoothing constant or speed
    mode: .continuous     // or .linear
))

// Presets
.tokenReveal(.fast)       // 80ms
.tokenReveal(.slow)       // 300ms
.tokenReveal(.disabled)   // no animation
.tokenReveal(.default)    // 150ms continuous
```

**Two reveal modes:**

- **Continuous** — a smooth cursor chases the stream at 60fps using exponential smoothing. Speeds up when behind, slows when close. `duration` is the smoothing time constant.
- **Linear** — constant-speed reveal at 60fps. `duration` controls speed (0.1 = 1000 chars/sec, 1.0 = 100 chars/sec). Keeps going at the same rate after streaming ends.

### Streaming Architecture

```
tokens -> StreamingMarkdownRenderer -> Document -> MarkdownBlocksView
              ^ throttleInterval          ^ tokenReveal config
              (content buffer)            (animation timing)
                                          ^ streamingTextEffect
                                          (per-glyph rendering)
                                          ^ revealGranularity
                                          (char/block/chunk/line)
```

A single 60fps cursor sweeps across all blocks. Each block receives its local cursor position and renders via `TextRenderer` for per-glyph control. The renderer's `throttleInterval` controls how often tokens are parsed into blocks. The view's `tokenReveal` config controls how the cursor animates. Keep `throttleInterval` low (0.016) so content is available for the cursor.

---

## Streaming Text Effects

Effects use iOS 18's `TextRenderer` API for per-glyph control over how text appears during streaming. Every effect works across paragraphs, headings, code blocks, lists, and blockquotes.

### Built-in effects

```swift
// Fade edge — solid text with fading edge near cursor
.streamingTextEffect(FadeEdgeEffect(edgeWidth: 8))

// Glow cursor — colored glow follows the cursor
.streamingTextEffect(GlowCursorEffect(glowColor: .cyan, glowRadius: 12))

// Wave — characters near the cursor bounce
.streamingTextEffect(WaveRevealEffect(amplitude: 6, wavelength: 12))

// Scale pop — characters scale up as they appear
.streamingTextEffect(ScalePopEffect(popWidth: 3))

// Rainbow — hue cycling near the cursor
.streamingTextEffect(RainbowEffect(trailLength: 16))

// Sparkle — particle burst at cursor position
.streamingTextEffect(SparkleEffect(sparkleCount: 8, color: .yellow))

// Fire trail — warm gradient glow trailing behind
.streamingTextEffect(FireTrailEffect(trailLength: 18))

// Explosion — expanding particle ring per character
.streamingTextEffect(ExplosionEffect())

// Nyan Cat — pixel-art cat with rainbow trail
.streamingTextEffect(NyanCatEffect())

// Matrix decode — character rain with block-level decode
// (use with .revealGranularity(.block) for full rain effect)
.streamingTextEffect(MatrixDecodeEffect())

// Phosphor CRT — green-screen terminal with scanlines
.streamingTextEffect(PhosphorCRTEffect(decayLength: 20))

// Shockwave — circular ripples displace nearby characters
.streamingTextEffect(ShockwaveEffect())

// Simple reveal — characters appear, nothing drawn past cursor
.streamingTextEffect(RevealEffect())
```

### Combining effects

```swift
// Compose multiple effects — first draws text, rest add decorations
.streamingTextEffect(CombinedEffect(
    WaveRevealEffect(amplitude: 4, wavelength: 10),
    GlowCursorEffect(glowColor: .orange, glowRadius: 10),
    SparkleEffect(sparkleCount: 10, color: .yellow)
))

// Or use the shorthand
let effect = WaveRevealEffect().combined(with: SparkleEffect())
```

### Custom effects

Implement the `StreamingTextEffect` protocol to create your own:

```swift
struct MyEffect: StreamingTextEffect {
    func draw(
        layout: Text.Layout,
        revealedCount: Int,
        settledCount: Int,
        time: Double,
        in ctx: inout GraphicsContext
    ) {
        // revealedCount: how many characters are visible (cursor position)
        // settledCount:  how many characters are done animating (based on granularity)
        // time:          continuous seconds, ticks at 60fps while streaming
        //                (use for effects that animate between token arrivals)
        //
        // index < settledCount            -> draw normally (settled)
        // settledCount <= index < revealed -> in the effect's active zone
        // index >= revealedCount           -> not yet revealed

        let trail = effectiveTrail(ownTrail: 10, revealedCount: revealedCount, settledCount: settledCount)

        forEachSlice(in: layout, { index, slice, context in
            guard index < revealedCount else { return false }
            let dist = revealedCount - index

            if dist <= trail {
                // Character is in the animation zone — apply your effect
                let t = Double(dist) / Double(trail)
                var c = context
                c.opacity = t  // fade in from cursor
                c.draw(slice)
            } else {
                // Settled — draw normally
                context.draw(slice)
            }
            return true
        }, context: &ctx)
    }
}
```

**Available helpers on `StreamingTextEffect`:**

| Helper | Purpose |
|--------|---------|
| `forEachSlice(in:_:context:)` | Iterate all character slices with global index |
| `effectiveTrail(ownTrail:revealedCount:settledCount:)` | Expand trail width to cover unsettled chars (respects granularity) |
| `totalCharCount(in:)` | Count all character slices in the layout |
| `drawRevealedAndGetCursorPoint(in:revealedCount:context:)` | Draw all revealed slices normally, return cursor position |

### Reveal Granularity

Controls when characters transition from the effect's active state to settled rendering. Text always reveals character-by-character — granularity controls the *effect scope*, not visibility.

```swift
// Characters settle as the cursor passes (default)
.revealGranularity(.character)

// Entire block stays in effect zone until complete, then settles at once
// e.g. Matrix + block = all chars show scrambled, whole block decodes when done
.revealGranularity(.block)

// Characters settle in chunks of N
.revealGranularity(.chunk(10))

// Characters settle line by line
.revealGranularity(.line)
```

A block is considered "complete" when either a subsequent block appears (meaning this block's content is finalized) or the stream ends. This prevents premature settling while a block is still receiving tokens.

With non-character granularity, blocks automatically get continuous 60fps animation via `TimelineView` while streaming. Effects receive a `time` parameter (seconds) that ticks independently of token arrivals — use it for effects that need to animate between bursts (e.g. Matrix rain falling). When the block completes, the timeline stops and text renders normally.

---

## Theming

Every element is configurable:

```swift
let theme = MarkdownTheme(
    bodyFont: .system(size: 15),
    foregroundColor: .white,
    paragraphSpacing: 10,
    codeBlock: CodeBlockStyle(
        backgroundColor: Color(white: 0.1),
        textColor: Color(white: 0.85),
        cornerRadius: 10
    ),
    blockquote: BlockquoteStyle(
        borderColor: .blue,
        borderWidth: 3,
        textColor: .gray
    ),
    table: TableStyle(
        headerBackground: Color(white: 0.15),
        backgroundStyle: .alternatingRows(even: Color(white: 0.08), odd: .clear)
    ),
    link: LinkStyle(color: .blue, underline: true)
)

MarkdownView("...")
    .markdownTheme(theme)
```

Built-in presets: `.default`, `.assistantBubble`, `.userBubble`, `.userBubblePending`

### Syntax highlighting themes

```swift
let highlighter = HighlightrCodeSyntaxHighlighter(theme: "atom-one-dark")

highlighter.setTheme("github")             // change at runtime
highlighter.availableThemes                 // ["atom-one-dark", "github", ...]

MarkdownView("...")
    .codeSyntaxHighlighter(highlighter)
```

---

## Custom Rendering

Replace the view for any block type:

```swift
struct MyProvider: MarkdownViewComponentProvider {
    func makeCodeBlock(language: String?, code: String, configuration: BlockConfiguration) -> some View {
        MyFancyCodeBlock(code: code, language: language)
    }

    func makeHeading(level: Int, content: [InlineNode], configuration: BlockConfiguration) -> some View {
        HeadingView(level: level, content: content)
    }
}

MarkdownView("...")
    .markdownComponentProvider(MyProvider())
```

Or replace just the code block renderer:

```swift
struct NeonCodeRenderer: CodeBlockRenderer {
    func makeBody(configuration: CodeBlockConfiguration) -> some View {
        Text(configuration.highlightedCode)
            .padding()
            .background(.black)
            .cornerRadius(12)
    }
}

MarkdownView("...")
    .codeBlockRenderer(NeonCodeRenderer())
```

---

## Processors

Transform the parsed AST before rendering:

| Processor | What it does |
|-----------|-------------|
| `LatexTransformer` | `$...$` to inline math, `$$...$$` to display math |
| `AutoLinkTransformer` | Raw URLs in text become tappable links |
| `CitationProcessor` | `[^1]` and `[1](url)` become citation nodes |
| `DefaultMarkdownProcessor` | Normalize whitespace, merge text nodes |

```swift
MarkdownView("...", processors: [
    AutoLinkTransformer(),
    LatexTransformer(),
    CitationProcessor(),
])
```

Write your own:

```swift
struct MyProcessor: MarkdownProcessor {
    func process(_ document: Document) -> Document {
        // Walk and transform the AST
    }
}
```

---

## AST Access

Parse markdown into a typed AST for programmatic use:

```swift
import Hairball

let parser = MarkdownParser()
let document = parser.parse("# Hello\n\n**bold** text")

for block in document.blocks {
    switch block {
    case .heading(let level, let content):
        print("H\(level): \(content)")
    case .paragraph(let content):
        for inline in content {
            switch inline {
            case .strong(let children): print("Bold: \(children)")
            case .text(let str): print("Text: \(str)")
            default: break
            }
        }
    default: break
    }
}
```

### Block types

`heading`, `paragraph`, `codeBlock`, `blockQuote`, `orderedList`, `unorderedList`, `table`, `thematicBreak`, `htmlBlock`, `latexBlock`, `blockDirective`, `customBlock`

### Inline types

`text`, `emphasis`, `strong`, `strikethrough`, `inlineCode`, `link`, `image`, `softBreak`, `hardBreak`, `lineBreak`, `inlineHTML`, `latex`, `citation`, `customInline`

---

## Building Documents Programmatically

```swift
let doc = Document(blocks: [
    .heading(level: 1, content: [.text("Title")]),
    .paragraph(content: [
        .text("Hello "),
        .strong(children: [.text("world")]),
    ]),
    .codeBlock(language: "swift", content: "let x = 42"),
    .unorderedList(tight: true, items: [
        ListItem(children: [.paragraph(content: [.text("Item 1")])], checkbox: .checked),
        ListItem(children: [.paragraph(content: [.text("Item 2")])], checkbox: .unchecked),
    ]),
])

MarkdownView(document: doc)
```

Or with the result builder:

```swift
MarkdownView {
    Heading(level: 1, "Title")
    Paragraph("Some text")
    CodeBlock(language: "swift", "let x = 42")
    if showOptional {
        Paragraph("Conditional content")
    }
}
```
