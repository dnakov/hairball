package io.github.sigkitten.hairball.demo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.sigkitten.hairball.compose.BlockquoteStyle
import io.github.sigkitten.hairball.compose.CombinedEffect
import io.github.sigkitten.hairball.compose.CitationStyle
import io.github.sigkitten.hairball.compose.CodeBlockStyle
import io.github.sigkitten.hairball.compose.ExplosionEffect
import io.github.sigkitten.hairball.compose.FadeEdgeEffect
import io.github.sigkitten.hairball.compose.FireTrailEffect
import io.github.sigkitten.hairball.compose.GlowCursorEffect
import io.github.sigkitten.hairball.compose.InlineCodeStyle
import io.github.sigkitten.hairball.compose.LinkStyle
import io.github.sigkitten.hairball.compose.MatrixDecodeEffect
import io.github.sigkitten.hairball.compose.MarkdownTheme
import io.github.sigkitten.hairball.compose.MarkdownView
import io.github.sigkitten.hairball.compose.NyanCatEffect
import io.github.sigkitten.hairball.compose.PhosphorCrtEffect
import io.github.sigkitten.hairball.compose.RainbowEffect
import io.github.sigkitten.hairball.compose.RevealGranularity
import io.github.sigkitten.hairball.compose.ShockwaveEffect
import io.github.sigkitten.hairball.compose.SparkleEffect
import io.github.sigkitten.hairball.compose.StreamingMarkdownContentView
import io.github.sigkitten.hairball.compose.StreamingMarkdownRenderer
import io.github.sigkitten.hairball.compose.TableBackgroundStyle
import io.github.sigkitten.hairball.compose.TableStyle
import io.github.sigkitten.hairball.compose.TokenRevealConfig
import io.github.sigkitten.hairball.compose.TokenRevealMode
import io.github.sigkitten.hairball.compose.WaveRevealEffect
import io.github.sigkitten.hairball.core.AutoLinkTransformer
import io.github.sigkitten.hairball.core.CitationProcessor
import io.github.sigkitten.hairball.core.LatexTransformer
import kotlin.math.roundToLong
import kotlin.random.Random
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { HairballDemoApp() }
    }
}

private enum class DemoScreen(val title: String) {
    Streaming("Streaming"),
    MarkdownTypes("Markdown Types"),
    ThemeShowcase("Theme Showcase"),
    ProcessorPipeline("Processor Pipeline"),
    AstInspector("AST Inspector"),
    CustomRendering("Custom Rendering"),
    ExpandableCode("Expandable Code"),
}

private enum class EffectChoice(val label: String) {
    FadeEdge("Fade"),
    Glow("Glow"),
    Wave("Wave"),
    Fire("Fire"),
    Sparkle("✨"),
    Rainbow("🌈"),
    Combo("🔥✨"),
    Explosion("💥"),
    Nyan("🐱"),
    Matrix("Matrix"),
    Crt("CRT"),
    Shockwave("Shock"),
    Instant("Off"),
}

private enum class GranularityChoice(val label: String) {
    Char("Char"),
    Chunk("Chunk"),
    Line("Line"),
    Block("Block"),
}

private enum class DemoChatRole {
    User,
    Assistant,
}

private data class DemoChatMessage(
    val id: Long,
    val role: DemoChatRole,
    val text: String,
    val renderer: StreamingMarkdownRenderer? = null,
)

private data class Conversation(
    val user: String,
    val response: String,
)

private val demoProcessors = listOf(
    AutoLinkTransformer(),
    LatexTransformer(),
    CitationProcessor(),
)

private val darkAssistantTheme = MarkdownTheme(
    bodyTextStyle = TextStyle(fontSize = 15.sp, lineHeight = 23.sp),
    foregroundColor = Color(0xFFE0E0E0),
    paragraphSpacingDp = 10,
    codeBlock = CodeBlockStyle(
        backgroundColor = Color(0xFF1A1A1A),
        textColor = Color(0xFFD5D5D5),
        textStyle = TextStyle(fontSize = 12.5.sp, lineHeight = 18.sp),
        cornerRadiusDp = 10,
        horizontalPaddingDp = 14,
        verticalPaddingDp = 12,
    ),
    inlineCode = InlineCodeStyle(
        backgroundColor = Color(0xFF262626),
        textColor = Color(0xFFF3B282),
    ),
    blockquote = BlockquoteStyle(
        borderColor = Color(0xFF4A4A4A),
        borderWidthDp = 2,
        backgroundColor = Color.Transparent,
        textColor = Color(0xFFA0A0A0),
    ),
    table = TableStyle(
        headerBackground = Color(0xFF1A1A1A),
        borderColor = Color(0xFF2E2E2E),
        borderWidthDp = 1,
        backgroundStyle = TableBackgroundStyle.Alternating,
    ),
    link = LinkStyle(color = Color(0xFF74AEFF)),
    citation = CitationStyle(
        textColor = Color(0xFF9A9A9A),
        backgroundColor = Color(0xFF202020),
    ),
)

private val streamingConversations = listOf(
    Conversation(
        "Explain Swift concurrency",
        """
        # Swift Concurrency

        Swift's concurrency model provides **structured concurrency** with `async`/`await`, actors, and task groups.

        ## Async/Await

        ```swift
        func fetchUser(id: Int) async throws -> User {
            let url = URL(string: "https://api.example.com/users/\(id)")!
            let (data, response) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(User.self, from: data)
        }
        ```

        ## Key Concepts

        | Concept | Purpose | Thread-safe? |
        |---------|---------|:---:|
        | `async`/`await` | Sequential async code | N/A |
        | `Actor` | Mutable state isolation | Yes |
        | `TaskGroup` | Parallel execution | Yes |

        > Prefer structured concurrency over detached work whenever you can.
        """.trimIndent(),
    ),
    Conversation(
        "How do neural networks work?",
        """
        # Neural Networks

        A neural network is a stack of layers that transforms input values into richer internal representations.

        ## Forward Pass

        $$
        z = \sum_{i=1}^{n} w_i x_i + b
        $$

        $$
        a = \sigma(z) = \frac{1}{1 + e^{-z}}
        $$

        ```python
        def forward(x, weights, bias):
            z = x @ weights + bias
            return sigmoid(z)
        ```

        - Feedforward networks process one pass at a time
        - CNNs specialize in spatial structure
        - Transformers use attention to model relationships
        """.trimIndent(),
    ),
    Conversation(
        "Write a sorting algorithm",
        """
        # Sorting Algorithms

        Here's a simple quick sort implementation:

        ```swift
        func quickSort<T: Comparable>(_ values: [T]) -> [T] {
            guard let pivot = values.first else { return [] }
            let rest = values.dropFirst()
            let lower = rest.filter { $0 <= pivot }
            let higher = rest.filter { $0 > pivot }
            return quickSort(lower) + [pivot] + quickSort(higher)
        }
        ```

        ## Complexity

        | Algorithm | Average | Worst |
        |-----------|---------|-------|
        | Quick sort | O(n log n) | O(n²) |
        | Merge sort | O(n log n) | O(n log n) |
        | Bubble sort | O(n²) | O(n²) |
        """.trimIndent(),
    ),
    Conversation(
        "Explain the solar system",
        """
        # The Solar System

        The solar system is centered on the Sun and includes planets, moons, dwarf planets, asteroids, and comets.

        1. Mercury, Venus, Earth, and Mars are rocky planets
        2. Jupiter and Saturn are gas giants
        3. Uranus and Neptune are ice giants

        ### Why orbits stay stable

        Gravity from the Sun keeps planets in orbit while their velocity keeps them moving forward.
        """.trimIndent(),
    ),
    Conversation(
        "Compare SQL vs NoSQL",
        """
        # SQL vs NoSQL

        SQL databases optimize for structured relations and strong schemas, while NoSQL systems trade schema rigidity for flexibility.

        | Feature | SQL | NoSQL |
        |---------|-----|--------|
        | Schema | Fixed | Flexible |
        | Joins | Strong | Limited / app-level |
        | Scaling | Vertical first | Horizontal first |

        Use the data model and consistency requirements to drive the choice.
        """.trimIndent(),
    ),
    Conversation(
        "What is quantum computing?",
        """
        # Quantum Computing

        Quantum computers operate on qubits, which can exist in superposition and become entangled.

        - Superposition lets a qubit represent multiple states
        - Entanglement links qubits so their states correlate
        - Measurement collapses the system into a concrete result

        Practical systems are still constrained by noise, error correction cost, and hardware scale.
        """.trimIndent(),
    ),
    Conversation(
        "Explain how compilers work",
        """
        # How Compilers Work

        A compiler transforms source code into a lower-level representation in stages:

        1. Lexing turns characters into tokens
        2. Parsing builds an AST
        3. Semantic analysis validates names and types
        4. Optimization improves the IR
        5. Code generation emits machine code or bytecode

        Block IDs, metadata, and streaming stages in this repo are conceptually similar pipeline steps.
        """.trimIndent(),
    ),
    Conversation(
        "Describe the water cycle",
        """
        # The Water Cycle

        Water constantly moves through evaporation, condensation, precipitation, and collection.

        ```text
        Ocean -> Evaporation -> Clouds -> Rain -> Rivers -> Ocean
        ```

        Climate change can intensify that cycle, causing heavier rainfall events and longer dry periods.
        """.trimIndent(),
    ),
)

private val lightBackground = Color(0xFFF6F1EB)
private val chatBackground = Color.Black

@Composable
private fun HairballDemoApp() {
    var screen by remember { mutableStateOf(DemoScreen.Streaming) }
    val background = if (screen == DemoScreen.Streaming) chatBackground else lightBackground

    Scaffold(containerColor = background) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(background)
                .padding(padding)
                .padding(vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LazyRow(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(DemoScreen.entries.toList(), key = { it.name }) { destination ->
                    val selected = destination == screen
                    if (selected) {
                        Button(onClick = { screen = destination }) {
                            Text(destination.title)
                        }
                    } else {
                        OutlinedButton(onClick = { screen = destination }) {
                            Text(destination.title)
                        }
                    }
                }
            }

            Box(modifier = Modifier.fillMaxSize()) {
                when (screen) {
                    DemoScreen.Streaming -> StreamingDemoScreen()
                    DemoScreen.MarkdownTypes -> DemoSurface {
                        MarkdownTypesScreen()
                    }
                    DemoScreen.ThemeShowcase -> DemoSurface {
                        ThemeShowcaseScreen()
                    }
                    DemoScreen.ProcessorPipeline -> DemoSurface {
                        ProcessorPipelineScreen()
                    }
                    DemoScreen.AstInspector -> DemoSurface {
                        PlaceholderScreen("AST inspector output is driven by the shared core parser fixtures.")
                    }
                    DemoScreen.CustomRendering -> DemoSurface {
                        PlaceholderScreen("Custom rendering hooks live in the public compose module interfaces.")
                    }
                    DemoScreen.ExpandableCode -> DemoSurface {
                        PlaceholderScreen("Expandable code behavior is owned by the compose renderer surface.")
                    }
                }
            }
        }
    }
}

@Composable
private fun DemoSurface(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        color = lightBackground,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun StreamingDemoScreen() {
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val messages = remember { mutableStateListOf<DemoChatMessage>() }
    var nextMessageId by remember { mutableLongStateOf(1L) }
    var shouldRun by remember { mutableStateOf(true) }
    var sessionNonce by remember { mutableIntStateOf(1) }
    var showControls by remember { mutableStateOf(true) }
    var effectChoice by remember { mutableStateOf(EffectChoice.FadeEdge) }
    var revealMode by remember { mutableStateOf("Smooth") }
    var revealDuration by remember { mutableStateOf(0.15f) }
    var tokenSpeedMs by remember { mutableStateOf(25f) }
    var granularityChoice by remember { mutableStateOf(GranularityChoice.Char) }
    var chunkSize by remember { mutableStateOf(10f) }
    var isStreaming by remember { mutableStateOf(false) }
    var streamUpdateCount by remember { mutableIntStateOf(0) }

    val currentTokenSpeed by rememberUpdatedState(tokenSpeedMs)
    val currentChunkSize by rememberUpdatedState(chunkSize.roundToLong().coerceAtLeast(2).toInt())
    val isAtBottom by remember {
        derivedStateOf {
            if (messages.isEmpty()) return@derivedStateOf true
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisible >= messages.lastIndex
        }
    }

    LaunchedEffect(effectChoice) {
        granularityChoice = effectChoice.recommendedGranularityChoice()
    }

    LaunchedEffect(sessionNonce, shouldRun) {
        if (!shouldRun) return@LaunchedEffect

        messages.clear()
        isStreaming = true
        streamUpdateCount = 0

        while (true) {
            for (conversation in streamingConversations) {
                messages += DemoChatMessage(
                    id = nextMessageId++,
                    role = DemoChatRole.User,
                    text = conversation.user,
                )
                streamUpdateCount += 1
                delay(300)

                val renderer = StreamingMarkdownRenderer(processors = demoProcessors)
                messages += DemoChatMessage(
                    id = nextMessageId++,
                    role = DemoChatRole.Assistant,
                    text = "",
                    renderer = renderer,
                )

                val tokens = tokenize(dedent(conversation.response), currentChunkSize)
                var index = 0
                var sinceUpdate = 0
                while (index < tokens.size) {
                    val burstSize = Random.nextInt(3, 13)
                    val end = minOf(index + burstSize, tokens.size)
                    for (tokenIndex in index until end) {
                        renderer.append(tokens[tokenIndex])
                    }
                    sinceUpdate += (end - index)
                    index = end

                    if (sinceUpdate >= 5) {
                        streamUpdateCount += 1
                        sinceUpdate = 0
                    }

                    if (effectChoice == EffectChoice.Instant) {
                        delay(8)
                    } else {
                        val pause = currentTokenSpeed.roundToLong() * Random.nextLong(2, 7)
                        delay(pause)
                    }
                }

                renderer.finish()
                streamUpdateCount += 1
                delay(800)
            }
        }
    }

    LaunchedEffect(streamUpdateCount, isStreaming, messages.size) {
        if (messages.isNotEmpty() && (isStreaming || isAtBottom)) {
            listState.scrollToItem(messages.lastIndex)
        }
    }

    Scaffold(
        containerColor = chatBackground,
        bottomBar = {
            StreamingControlsBar(
                showControls = showControls,
                onToggleControls = { showControls = !showControls },
                effectChoice = effectChoice,
                onEffectChoiceChange = { effectChoice = it },
                revealMode = revealMode,
                onRevealModeChange = { revealMode = it },
                revealDuration = revealDuration,
                onRevealDurationChange = { revealDuration = it },
                tokenSpeedMs = tokenSpeedMs,
                onTokenSpeedMsChange = { tokenSpeedMs = it },
                granularityChoice = granularityChoice,
                onGranularityChoiceChange = { granularityChoice = it },
                chunkSize = chunkSize,
                onChunkSizeChange = { chunkSize = it },
                messagesEmpty = messages.isEmpty(),
                onStart = {
                    shouldRun = true
                    sessionNonce += 1
                },
                onClear = {
                    shouldRun = false
                    sessionNonce += 1
                    messages.clear()
                    isStreaming = false
                    streamUpdateCount = 0
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(chatBackground),
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                items(messages, key = { it.id }) { message ->
                    MessageRow(
                        message = message,
                        effectChoice = effectChoice,
                        granularityChoice = granularityChoice,
                        chunkSize = currentChunkSize,
                        revealMode = revealMode,
                        revealDuration = revealDuration,
                    )
                }
            }

            if (!isAtBottom && messages.isNotEmpty()) {
                Button(
                    onClick = {
                        if (messages.isNotEmpty()) {
                            coroutineScope.launch {
                                listState.animateScrollToItem(messages.lastIndex)
                            }
                        }
                    },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 76.dp),
                ) {
                    Text("Jump to Bottom")
                }
            }
        }
    }
}

@Composable
private fun StreamingControlsBar(
    showControls: Boolean,
    onToggleControls: () -> Unit,
    effectChoice: EffectChoice,
    onEffectChoiceChange: (EffectChoice) -> Unit,
    revealMode: String,
    onRevealModeChange: (String) -> Unit,
    revealDuration: Float,
    onRevealDurationChange: (Float) -> Unit,
    tokenSpeedMs: Float,
    onTokenSpeedMsChange: (Float) -> Unit,
    granularityChoice: GranularityChoice,
    onGranularityChoiceChange: (GranularityChoice) -> Unit,
    chunkSize: Float,
    onChunkSizeChange: (Float) -> Unit,
    messagesEmpty: Boolean,
    onStart: () -> Unit,
    onClear: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF0F0F10))
            .navigationBarsPadding(),
    ) {
        HorizontalDivider(color = Color(0xFF1F1F1F))

        Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            OutlinedButton(onClick = onToggleControls, modifier = Modifier.padding(top = 6.dp)) {
                Text(if (showControls) "Controls ▼" else "Controls ▲")
            }
        }

        if (showControls) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ChoiceRow(
                    title = "Effect",
                    options = EffectChoice.entries.toList(),
                    selected = effectChoice,
                    label = { it.label },
                    onSelect = onEffectChoiceChange,
                )

                if (effectChoice != EffectChoice.Instant) {
                    ChoiceRow(
                        title = "Mode",
                        options = listOf("Smooth", "Linear"),
                        selected = revealMode,
                        label = { it },
                        onSelect = onRevealModeChange,
                    )

                    ChoiceRow(
                        title = "Granularity",
                        options = GranularityChoice.entries.toList(),
                        selected = granularityChoice,
                        label = { it.label },
                        onSelect = onGranularityChoiceChange,
                    )

                    if (granularityChoice == GranularityChoice.Chunk) {
                        SliderRow(
                            label = "Chunk Size",
                            value = chunkSize,
                            valueLabel = "${chunkSize.roundToLong()}",
                            range = 2f..50f,
                            onValueChange = onChunkSizeChange,
                        )
                    }

                    SliderRow(
                        label = if (revealMode == "Smooth") "Smoothing" else "Speed",
                        value = revealDuration,
                        valueLabel = "${(revealDuration * 1000).roundToLong()}ms",
                        range = 0.02f..0.8f,
                        onValueChange = onRevealDurationChange,
                    )
                }

                SliderRow(
                    label = "Token Speed",
                    value = tokenSpeedMs,
                    valueLabel = "${tokenSpeedMs.roundToLong()}ms",
                    range = 5f..100f,
                    onValueChange = onTokenSpeedMsChange,
                )
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(20.dp),
                color = Color(0xFF1E1E1E),
            ) {
                Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                    Text(
                        "Message...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF6D6D6D),
                    )
                }
            }

            if (messagesEmpty) {
                Button(onClick = onStart) {
                    Text("Start")
                }
            } else {
                OutlinedButton(onClick = onClear) {
                    Text("Reset")
                }
            }
        }
    }
}

@Composable
private fun <T> ChoiceRow(
    title: String,
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = Color(0xFF8E8E93))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(options, key = { label(it) }) { option ->
                if (option == selected) {
                    Button(onClick = { onSelect(option) }) {
                        Text(label(option))
                    }
                } else {
                    OutlinedButton(onClick = { onSelect(option) }) {
                        Text(label(option))
                    }
                }
            }
        }
    }
}

@Composable
private fun SliderRow(
    label: String,
    value: Float,
    valueLabel: String,
    range: ClosedFloatingPointRange<Float>,
    onValueChange: (Float) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            label,
            modifier = Modifier.size(width = 88.dp, height = 20.dp),
            style = MaterialTheme.typography.labelMedium,
            color = Color(0xFF8E8E93),
        )
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = range,
            modifier = Modifier.weight(1f),
        )
        Text(valueLabel, style = MaterialTheme.typography.labelMedium, color = Color(0xFF8E8E93))
    }
}

@Composable
private fun MessageRow(
    message: DemoChatMessage,
    effectChoice: EffectChoice,
    granularityChoice: GranularityChoice,
    chunkSize: Int,
    revealMode: String,
    revealDuration: Float,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        if (message.role == DemoChatRole.User) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.End,
            ) {
                Spacer(modifier = Modifier.weight(1f))
                Surface(
                    color = Color(0xFF2E2E2E),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text(
                        text = message.text,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White,
                    )
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                if (message.renderer != null) {
                    StreamingMarkdownContentView(
                        renderer = message.renderer,
                        theme = darkAssistantTheme,
                        streamingEffect = effectChoice.toStreamingEffect(),
                        revealGranularity = granularityChoice.toRevealGranularity(chunkSize),
                        revealConfig = if (effectChoice == EffectChoice.Instant) {
                            TokenRevealConfig.Disabled
                        } else {
                            TokenRevealConfig(
                                duration = revealDuration.toDouble(),
                                mode = if (revealMode == "Linear") TokenRevealMode.Linear else TokenRevealMode.Continuous,
                            )
                        },
                    )
                } else {
                    MarkdownView(
                        markdown = message.text,
                        theme = darkAssistantTheme,
                        processors = demoProcessors,
                    )
                }
            }
        }

        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            color = Color(0xFF1F1F1F),
        )
    }
}

private fun EffectChoice.toStreamingEffect() = when (this) {
    EffectChoice.FadeEdge -> FadeEdgeEffect(edgeWidth = 8)
    EffectChoice.Glow -> GlowCursorEffect(glowRadius = 12f)
    EffectChoice.Wave -> WaveRevealEffect(amplitude = 6f, wavelength = 12)
    EffectChoice.Fire -> FireTrailEffect(trailLength = 18)
    EffectChoice.Sparkle -> SparkleEffect(sparkleCount = 8)
    EffectChoice.Rainbow -> RainbowEffect(trailLength = 16)
    EffectChoice.Combo -> CombinedEffect(
        effects = listOf(
            WaveRevealEffect(amplitude = 4f, wavelength = 10),
            GlowCursorEffect(glowRadius = 10f),
            SparkleEffect(sparkleCount = 10),
        ),
    )
    EffectChoice.Explosion -> ExplosionEffect()
    EffectChoice.Nyan -> NyanCatEffect()
    EffectChoice.Matrix -> MatrixDecodeEffect()
    EffectChoice.Crt -> PhosphorCrtEffect()
    EffectChoice.Shockwave -> ShockwaveEffect()
    EffectChoice.Instant -> null
}

private fun GranularityChoice.toRevealGranularity(chunkSize: Int): RevealGranularity = when (this) {
    GranularityChoice.Char -> RevealGranularity.Character
    GranularityChoice.Chunk -> RevealGranularity.Chunk(chunkSize)
    GranularityChoice.Line -> RevealGranularity.Line
    GranularityChoice.Block -> RevealGranularity.Block
}

private fun EffectChoice.recommendedGranularityChoice(): GranularityChoice = when (toStreamingEffect()?.recommendedGranularity) {
    RevealGranularity.Block -> GranularityChoice.Block
    else -> GranularityChoice.Char
}

@Composable
private fun MarkdownTypesScreen() {
    MarkdownView(
        markdown = sampleMarkdown,
        theme = MarkdownTheme.Default,
        processors = demoProcessors,
    )
}

@Composable
private fun ThemeShowcaseScreen() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Assistant Bubble", style = MaterialTheme.typography.titleMedium)
        MarkdownView("Paragraph with `code` and **bold**.", theme = darkAssistantTheme)
        Text("User Bubble", style = MaterialTheme.typography.titleMedium)
        MarkdownView("Paragraph with `code` and **bold**.", theme = MarkdownTheme.UserBubble)
    }
}

@Composable
private fun ProcessorPipelineScreen() {
    MarkdownView(
        markdown = "Visit https://example.com and cite [1](https://example.com \"Example\") with ${'$'}E = mc^2${'$'}.",
        processors = demoProcessors,
    )
}

@Composable
private fun PlaceholderScreen(message: String) {
    Text(
        text = message,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 24.dp),
        style = MaterialTheme.typography.bodyLarge,
        color = Color(0xFF3F342B),
    )
}

private fun dedent(text: String): String {
    val lines = text.split('\n')
    val nonEmpty = lines.filter { it.trim().isNotEmpty() }
    if (nonEmpty.isEmpty()) return text
    val minIndent = nonEmpty.minOf { line -> line.takeWhile { it == ' ' }.length }
    if (minIndent <= 0) return text
    return lines.joinToString("\n") { line ->
        if (line.length >= minIndent) line.drop(minIndent) else line
    }
}

private fun tokenize(text: String, preferredChunkSize: Int): List<String> {
    val tokens = mutableListOf<String>()
    val builder = StringBuilder()
    for (character in text) {
        builder.append(character)
        val atBreak = character == ' ' || character == '\n' || character == '.' || character == ',' || character == ':' || character == '`'
        val chunkSize = Random.nextInt(3, maxOf(4, preferredChunkSize))
        if (atBreak || builder.length >= chunkSize) {
            tokens += builder.toString()
            builder.clear()
        }
    }
    if (builder.isNotEmpty()) {
        tokens += builder.toString()
    }
    return tokens
}

private val sampleMarkdown = """
# Heading 1
## Heading 2

This is a paragraph with **bold**, *italic*, ~~strikethrough~~, and `inline code`.

- [x] Completed task
- [ ] Pending task

| Feature | Status |
|---------|--------|
| Parsing | Done |
| Streaming | In Progress |

Inline math ${'$'}E = mc^2${'$'} and citation [1](https://example.com "Example").
""".trimIndent()
