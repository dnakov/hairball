import SwiftUI
import Hairball
import HairballUI

// MARK: - Animator Picker

// MARK: - Effect Picker

enum EffectChoice: String, CaseIterable {
    case fadeEdge = "Fade"
    case glow = "Glow"
    case wave = "Wave"
    case fire = "Fire"
    case sparkle = "✨"
    case rainbow = "🌈"
    case combo = "🔥✨"
    case explosion = "💥"
    case nyan = "🐱"
    case matrix = "Matrix"
    case crt = "CRT"
    case shockwave = "Shock"
    case instant = "Off"

    var effect: (any StreamingTextEffect)? {
        switch self {
        case .fadeEdge: return FadeEdgeEffect(edgeWidth: 8)
        case .glow: return GlowCursorEffect(glowColor: .cyan, glowRadius: 12)
        case .wave: return WaveRevealEffect(amplitude: 6, wavelength: 12)
        case .fire: return FireTrailEffect(trailLength: 18)
        case .sparkle: return SparkleEffect(sparkleCount: 8, color: .yellow)
        case .rainbow: return RainbowEffect(trailLength: 16)
        case .explosion: return ExplosionEffect()
        case .nyan: return NyanCatEffect()
        case .matrix: return MatrixDecodeEffect()
        case .crt: return PhosphorCRTEffect()
        case .shockwave: return ShockwaveEffect()
        case .combo: return CombinedEffect(
            WaveRevealEffect(amplitude: 4, wavelength: 10),
            GlowCursorEffect(glowColor: .orange, glowRadius: 10),
            SparkleEffect(sparkleCount: 10, color: .yellow)
        )
        case .instant: return nil
        }
    }
}

enum GranularityChoice: String, CaseIterable {
    case char = "Char"
    case chunk = "Chunk"
    case line = "Line"
    case block = "Block"

    func granularity(chunkSize: Int = 10) -> RevealGranularity {
        switch self {
        case .char: return .character
        case .chunk: return .chunk(chunkSize)
        case .line: return .line
        case .block: return .block
        }
    }
}

/// Applies StreamingTextEffect when on iOS 18+, no-op otherwise.
struct EffectModifier: ViewModifier {
    let choice: EffectChoice
    let granularity: RevealGranularity

    func body(content: Content) -> some View {
        if let effect = choice.effect {
            content
                .streamingTextEffect(effect)
                .revealGranularity(granularity)
        } else {
            content
        }
    }
}

struct StreamingChatDemoView: View {
    @StateObject private var chatVM = ChatViewModel()
    @State private var isAtBottom = true
    @State private var scrollToBottomTrigger = 0
    @State private var effectChoice: EffectChoice = .fadeEdge
    @State private var revealMode: TokenRevealMode = .continuous
    @State private var revealDuration: Double = 0.15
    @State private var tokenSpeed: Double = 25  // ms per token
    @State private var granularityChoice: GranularityChoice = .char
    @State private var chunkSize: Double = 10
    @State private var showControls: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(chatVM.messages) { msg in
                            MessageRow(message: msg)
                        }

                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear { isAtBottom = true }
                            .onDisappear { isAtBottom = false }
                    }
                }
                .onChange(of: scrollToBottomTrigger) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                // Auto-scroll when streaming and user is at bottom
                .onChange(of: chatVM.streamUpdateCount) { _ in
                    if isAtBottom && chatVM.isStreaming {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .tokenReveal(effectChoice == .instant
                    ? .disabled
                    : TokenRevealConfig(duration: revealDuration, mode: revealMode)
                )
                .modifier(EffectModifier(choice: effectChoice, granularity: granularityChoice.granularity(chunkSize: Int(chunkSize))))
            }

            // Scroll-to-bottom button — only visible when not at bottom
            if !isAtBottom {
                Button {
                    scrollToBottomTrigger += 1
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white, Color(white: 0.2))
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                }
                .padding(.bottom, 70)
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.2), value: isAtBottom)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(Color(white: 0.2)).frame(height: 0.5)

                // Toggle controls visibility
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        SwiftUI.Text("Controls")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.5))
                        Image(systemName: showControls ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                            .foregroundColor(Color(white: 0.4))
                    }
                    .padding(.top, 6)
                }

                if showControls {
                    VStack(spacing: 6) {
                        // Animator style
                        HStack(spacing: 8) {
                            Picker("Effect", selection: $effectChoice) {
                                ForEach(EffectChoice.allCases, id: \.self) { choice in
                                    SwiftUI.Text(choice.rawValue).tag(choice)
                                }
                            }
                            .pickerStyle(.segmented)

                            if effectChoice != .instant {
                                Picker("Mode", selection: $revealMode) {
                                    SwiftUI.Text("Smooth").tag(TokenRevealMode.continuous)
                                    SwiftUI.Text("Linear").tag(TokenRevealMode.linear)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            }
                        }

                        if effectChoice != .instant {
                            HStack(spacing: 8) {
                                SwiftUI.Text("Reveal")
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.5))
                                Picker("Granularity", selection: $granularityChoice) {
                                    ForEach(GranularityChoice.allCases, id: \.self) { g in
                                        SwiftUI.Text(g.rawValue).tag(g)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if granularityChoice == .chunk {
                                sliderRow(
                                    label: "Chunk Size",
                                    value: $chunkSize,
                                    range: 2...50,
                                    display: "\(Int(chunkSize))"
                                )
                            }

                            let label = revealMode == .continuous ? "Smoothing" : "Speed"
                            sliderRow(
                                label: label,
                                value: $revealDuration,
                                range: 0.02...0.8,
                                display: "\(Int(revealDuration * 1000))ms"
                            )
                        }

                        sliderRow(
                            label: "Token Speed",
                            value: $tokenSpeed,
                            range: 5...100,
                            display: "\(Int(tokenSpeed))ms"
                        )

                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack(spacing: 10) {
                    HStack {
                        SwiftUI.Text("Message...")
                            .foregroundColor(Color(white: 0.4))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onTapGesture {
                        if !chatVM.isStreaming && chatVM.messages.isEmpty {
                            chatVM.runStressTest()
                        }
                    }

                    if chatVM.messages.isEmpty {
                        Button { chatVM.runStressTest() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    } else {
                        Button { chatVM.clear() } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(white: 0.4))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(white: 0.06))
        }
        .scrollContentBackground(.hidden)
        .background { Color.black.ignoresSafeArea() }
        .onAppear {
            if chatVM.messages.isEmpty {
                chatVM.runStressTest()
            }
        }
        .onChange(of: revealDuration) { _ in
            syncThrottle()
        }
        .onChange(of: revealMode) { _ in
            syncThrottle()
        }
        .onChange(of: tokenSpeed) { newSpeed in
            chatVM.tokenDelayNs = UInt64(newSpeed * 1_000_000)
        }
    }

    private func syncThrottle() {
        let interval: TimeInterval = 0.016
        chatVM.throttleInterval = interval
        for msg in chatVM.messages {
            msg.renderer?.throttleInterval = interval
        }
    }
}

// MARK: - Slider Row

private func sliderRow(
    label: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    display: String
) -> some View {
    HStack(spacing: 8) {
        SwiftUI.Text(label)
            .font(.caption)
            .foregroundColor(Color(white: 0.5))
            .frame(width: 90, alignment: .leading)
        Slider(value: value, in: range)
            .tint(Color(white: 0.4))
        SwiftUI.Text(display)
            .font(.caption.monospacedDigit())
            .foregroundColor(Color(white: 0.5))
            .frame(width: 42, alignment: .trailing)
    }
}

// MARK: - View Model

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMsg] = []
    @Published var isStreaming = false
    @Published var streamUpdateCount = 0
    var throttleInterval: TimeInterval = 0.016
    var tokenDelayNs: UInt64 = 25_000_000
    private var streamingTask: Task<Void, Never>?

    private let conversations: [(user: String, response: String)] = [
        ("Explain Swift concurrency", ChatViewModel.swiftConcurrencyResponse),
        ("How do neural networks work?", ChatViewModel.neuralNetworkResponse),
        ("Write a sorting algorithm", ChatViewModel.sortingAlgorithmResponse),
        ("Explain the solar system", ChatViewModel.solarSystemResponse),
        ("Compare SQL vs NoSQL", ChatViewModel.sqlVsNoSQLResponse),
        ("What is quantum computing?", ChatViewModel.quantumComputingResponse),
        ("Explain how compilers work", ChatViewModel.compilerResponse),
        ("Describe the water cycle", ChatViewModel.waterCycleResponse),
    ]

    func clear() {
        streamingTask?.cancel()
        messages = []
        isStreaming = false
    }

    func runStressTest() {
        streamingTask?.cancel()
        messages = []
        isStreaming = true

        streamingTask = Task {
            // Loop forever, streaming each conversation one at a time
            while !Task.isCancelled {
                for convo in conversations {
                    guard !Task.isCancelled else { return }

                    // User message
                    messages.append(ChatMsg(role: .user, text: convo.user))
                    streamUpdateCount += 1

                    // Small pause before assistant starts
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }

                    // Stream assistant response
                    let renderer = StreamingMarkdownRenderer(
                        processors: [AutoLinkTransformer(), LatexTransformer(), CitationProcessor()],
                        throttleInterval: throttleInterval
                    )
                    messages.append(ChatMsg(role: .assistant, text: "", renderer: renderer))

                    let tokens = tokenize(dedent(convo.response))
                    var tokensSinceUpdate = 0
                    var i = 0
                    while i < tokens.count {
                        guard !Task.isCancelled else { return }

                        // Simulate LLM behavior: occasional bursts of 3-12 tokens
                        // with pauses between, like real API streaming
                        let burstSize = Int.random(in: 3...12)
                        let end = min(i + burstSize, tokens.count)
                        for j in i..<end {
                            renderer.append(tokens[j])
                        }
                        tokensSinceUpdate += (end - i)
                        i = end

                        if tokensSinceUpdate >= 5 {
                            streamUpdateCount += 1
                            tokensSinceUpdate = 0
                        }

                        // Pause between bursts — varies like real network chunks
                        let delay = tokenDelayNs
                        let burstPause = delay * UInt64.random(in: 2...6)
                        try? await Task.sleep(nanoseconds: burstPause)
                    }
                    renderer.finish()
                    streamUpdateCount += 1

                    // Pause between conversations
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            }
            isStreaming = false
        }
    }

    /// Strip common leading whitespace from all lines (Python-style dedent).
    private func dedent(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmptyLines.isEmpty else { return text }
        let minIndent = nonEmptyLines.map { line in
            line.prefix(while: { $0 == " " }).count
        }.min() ?? 0
        guard minIndent > 0 else { return text }
        return lines.map { line in
            if line.count >= minIndent {
                return String(line.dropFirst(minIndent))
            }
            return line
        }.joined(separator: "\n")
    }

    /// Simulates LLM token chunking — variable-size pieces (3-8 chars),
    /// breaking on word/punctuation boundaries like real tokenizers.
    private func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var cur = ""
        for c in text {
            cur.append(c)
            let len = cur.count
            let atBreak = c == " " || c == "\n" || c == "." || c == "," || c == ":" || c == "`"
            let chunkSize = Int.random(in: 3...8)
            if atBreak || len >= chunkSize {
                tokens.append(cur)
                cur = ""
            }
        }
        if !cur.isEmpty { tokens.append(cur) }
        return tokens
    }

    // MARK: - Long test responses

    static let swiftConcurrencyResponse = """
    # Swift Concurrency

    Swift's concurrency model provides **structured concurrency** with `async`/`await`, actors, and task groups.

    ## Async/Await

    The foundation of Swift concurrency is the ability to write asynchronous code that looks synchronous:

    ```swift
    func fetchUser(id: Int) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\\(id)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        return try JSONDecoder().decode(User.self, from: data)
    }
    ```

    ## Actors

    Actors protect mutable state from data races:

    ```swift
    actor BankAccount {
        private var balance: Decimal = 0

        func deposit(_ amount: Decimal) {
            balance += amount
        }

        func withdraw(_ amount: Decimal) throws -> Decimal {
            guard balance >= amount else {
                throw BankError.insufficientFunds
            }
            balance -= amount
            return amount
        }

        var currentBalance: Decimal { balance }
    }
    ```

    ## Task Groups

    For parallel work, use `TaskGroup`:

    ```swift
    func fetchAllUsers(ids: [Int]) async throws -> [User] {
        try await withThrowingTaskGroup(of: User.self) { group in
            for id in ids {
                group.addTask {
                    try await fetchUser(id: id)
                }
            }

            var users: [User] = []
            for try await user in group {
                users.append(user)
            }
            return users
        }
    }
    ```

    ## Key Concepts

    | Concept | Purpose | Thread-safe? |
    |---------|---------|:---:|
    | `async`/`await` | Sequential async code | N/A |
    | `Actor` | Mutable state isolation | Yes |
    | `TaskGroup` | Parallel execution | Yes |
    | `AsyncSequence` | Streaming values | Yes |
    | `Sendable` | Cross-boundary safety | Yes |

    > **Important**: Always prefer structured concurrency over unstructured `Task { }` blocks. Structured tasks are automatically cancelled when their parent scope exits.

    ## AsyncSequence

    For streaming data:

    ```swift
    for await line in url.lines {
        process(line)
    }
    ```

    ---

    Swift concurrency makes it **safe** and **readable** to write concurrent code without the pitfalls of traditional threading.
    """

    static let neuralNetworkResponse = """
    # Neural Networks

    A neural network is a computational model inspired by biological neural networks. It consists of **layers** of interconnected nodes (neurons).

    ## Architecture

    ```
    Input Layer → Hidden Layer(s) → Output Layer
       [x₁]         [h₁] [h₂]         [y₁]
       [x₂]   →     [h₃] [h₄]   →     [y₂]
       [x₃]         [h₅] [h₆]
    ```

    ## Forward Propagation

    Each neuron computes a weighted sum plus bias, then applies an activation function:

    $$
    z = \\sum_{i=1}^{n} w_i x_i + b
    $$

    $$
    a = \\sigma(z) = \\frac{1}{1 + e^{-z}}
    $$

    ## Implementation

    ```python
    import numpy as np

    class NeuralNetwork:
        def __init__(self, layers):
            self.weights = []
            self.biases = []
            for i in range(len(layers) - 1):
                w = np.random.randn(layers[i], layers[i+1]) * 0.01
                b = np.zeros((1, layers[i+1]))
                self.weights.append(w)
                self.biases.append(b)

        def forward(self, X):
            self.activations = [X]
            for w, b in zip(self.weights, self.biases):
                z = self.activations[-1] @ w + b
                a = self.sigmoid(z)
                self.activations.append(a)
            return self.activations[-1]

        def sigmoid(self, z):
            return 1 / (1 + np.exp(-z))

        def train(self, X, y, epochs=1000, lr=0.01):
            for epoch in range(epochs):
                output = self.forward(X)
                loss = np.mean((y - output) ** 2)
                self.backward(y, lr)
                if epoch % 100 == 0:
                    print(f"Epoch {epoch}, Loss: {loss:.4f}")
    ```

    ## Types of Neural Networks

    - **Feedforward (FNN)**: Basic architecture, data flows one direction
    - **Convolutional (CNN)**: Specialized for images and spatial data
    - **Recurrent (RNN)**: Processes sequential data with memory
    - **Transformer**: Attention-based, powers modern LLMs
    - **GAN**: Two networks competing (generator + discriminator)

    ## Loss Functions

    | Task | Loss Function | Formula |
    |------|--------------|---------|
    | Regression | MSE | $\\frac{1}{n}\\sum(y - \\hat{y})^2$ |
    | Binary | Cross-Entropy | $-[y\\log(p) + (1-y)\\log(1-p)]$ |
    | Multi-class | Softmax + CE | $-\\sum y_i \\log(p_i)$ |

    > Neural networks learn by adjusting weights through **backpropagation** — computing gradients of the loss with respect to each weight and updating them in the direction that minimizes the loss.

    ---

    The power of neural networks comes from their ability to learn **nonlinear** representations automatically from data.
    """

    static let sortingAlgorithmResponse = """
    # Sorting Algorithms

    Here are the major sorting algorithms compared.

    ## Quick Sort

    Average case $O(n \\log n)$, worst case $O(n^2)$:

    ```swift
    func quickSort<T: Comparable>(_ array: inout [T], low: Int, high: Int) {
        if low < high {
            let pivot = partition(&array, low: low, high: high)
            quickSort(&array, low: low, high: pivot - 1)
            quickSort(&array, low: pivot + 1, high: high)
        }
    }

    func partition<T: Comparable>(_ array: inout [T], low: Int, high: Int) -> Int {
        let pivot = array[high]
        var i = low - 1

        for j in low..<high {
            if array[j] <= pivot {
                i += 1
                array.swapAt(i, j)
            }
        }
        array.swapAt(i + 1, high)
        return i + 1
    }
    ```

    ## Merge Sort

    Guaranteed $O(n \\log n)$:

    ```swift
    func mergeSort<T: Comparable>(_ array: [T]) -> [T] {
        guard array.count > 1 else { return array }

        let mid = array.count / 2
        let left = mergeSort(Array(array[..<mid]))
        let right = mergeSort(Array(array[mid...]))

        return merge(left, right)
    }

    func merge<T: Comparable>(_ left: [T], _ right: [T]) -> [T] {
        var result: [T] = []
        var i = 0, j = 0

        while i < left.count && j < right.count {
            if left[i] <= right[j] {
                result.append(left[i]); i += 1
            } else {
                result.append(right[j]); j += 1
            }
        }
        result.append(contentsOf: left[i...])
        result.append(contentsOf: right[j...])
        return result
    }
    ```

    ## Comparison Table

    | Algorithm | Best | Average | Worst | Space | Stable? |
    |-----------|------|---------|-------|-------|---------|
    | Quick Sort | $O(n\\log n)$ | $O(n\\log n)$ | $O(n^2)$ | $O(\\log n)$ | No |
    | Merge Sort | $O(n\\log n)$ | $O(n\\log n)$ | $O(n\\log n)$ | $O(n)$ | Yes |
    | Heap Sort | $O(n\\log n)$ | $O(n\\log n)$ | $O(n\\log n)$ | $O(1)$ | No |
    | Bubble Sort | $O(n)$ | $O(n^2)$ | $O(n^2)$ | $O(1)$ | Yes |
    | Insertion Sort | $O(n)$ | $O(n^2)$ | $O(n^2)$ | $O(1)$ | Yes |

    > **Tip**: For small arrays (< 20 elements), insertion sort often outperforms quicksort due to lower overhead.

    ---

    In practice, most standard libraries use **Timsort** (a hybrid of merge sort + insertion sort) or **Introsort** (quicksort + heapsort fallback).
    """

    static let solarSystemResponse = """
    # The Solar System

    Our solar system consists of the **Sun**, eight planets, dwarf planets, moons, asteroids, and comets.

    ## The Planets

    1. **Mercury** — Smallest planet, closest to the Sun. Surface temperature ranges from -180C to 430C.
    2. **Venus** — Hottest planet due to greenhouse effect. Rotates *backwards*.
    3. **Earth** — Only known planet with life. One moon.
    4. **Mars** — The "Red Planet". Two small moons: Phobos and Deimos.
    5. **Jupiter** — Largest planet. Great Red Spot storm. 95 known moons.
    6. **Saturn** — Famous for its rings. 146 known moons.
    7. **Uranus** — Rotates on its side. Ice giant.
    8. **Neptune** — Farthest planet. Strongest winds in the solar system.

    ## Key Statistics

    | Planet | Diameter (km) | Distance from Sun (AU) | Moons |
    |--------|:---:|:---:|:---:|
    | Mercury | 4,879 | 0.39 | 0 |
    | Venus | 12,104 | 0.72 | 0 |
    | Earth | 12,756 | 1.00 | 1 |
    | Mars | 6,792 | 1.52 | 2 |
    | Jupiter | 142,984 | 5.20 | 95 |
    | Saturn | 120,536 | 9.54 | 146 |
    | Uranus | 51,118 | 19.2 | 28 |
    | Neptune | 49,528 | 30.1 | 16 |

    > The **Kuiper Belt** beyond Neptune contains dwarf planets like Pluto, Eris, and Makemake.

    ## The Sun

    - Type: G2V main-sequence star
    - Age: ~4.6 billion years
    - Core temperature: ~15 million degrees C
    - Composition: ~73% hydrogen, ~25% helium

    ---

    The solar system formed approximately **4.6 billion years ago** from a giant molecular cloud.
    """

    static let sqlVsNoSQLResponse = """
    # SQL vs NoSQL Databases

    Choosing between SQL and NoSQL depends on your data model, scale, and consistency requirements.

    ## SQL (Relational)

    ```sql
    CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE orders (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        total DECIMAL(10, 2) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending'
    );

    -- Join query
    SELECT u.name, COUNT(o.id) as order_count, SUM(o.total) as total_spent
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
    GROUP BY u.id, u.name
    HAVING COUNT(o.id) > 5
    ORDER BY total_spent DESC;
    ```

    ## NoSQL (Document)

    ```json
    {
        "_id": "user_123",
        "name": "Jane Smith",
        "email": "jane@example.com",
        "orders": [
            { "id": "ord_1", "total": 59.99, "status": "delivered" },
            { "id": "ord_2", "total": 129.00, "status": "pending" }
        ],
        "preferences": {
            "theme": "dark",
            "notifications": true
        }
    }
    ```

    ## Comparison

    | Feature | SQL | NoSQL |
    |---------|-----|-------|
    | Schema | Fixed, predefined | Flexible, dynamic |
    | Scaling | Vertical (scale up) | Horizontal (scale out) |
    | Consistency | Strong (ACID) | Eventual (BASE) |
    | Joins | Native support | Manual/denormalized |
    | Best for | Complex queries | High throughput |
    | Examples | PostgreSQL, MySQL | MongoDB, Cassandra |

    > **ACID** = Atomicity, Consistency, Isolation, Durability
    > **BASE** = Basically Available, Soft state, Eventually consistent

    - [x] Use SQL for complex relationships and transactions
    - [x] Use NoSQL for flexible schemas and horizontal scaling
    - [ ] There is no universal "best" choice

    ---

    Many modern architectures use **both** — SQL for transactional data and NoSQL for caching, analytics, or unstructured content.
    """

    static let quantumComputingResponse = """
    # Quantum Computing

    Quantum computing leverages quantum mechanical phenomena to process information in fundamentally new ways.

    ## Qubits vs Classical Bits

    Classical bits are either `0` or `1`. Qubits can exist in **superposition** — a combination of both:

    $$
    |\\psi\\rangle = \\alpha|0\\rangle + \\beta|1\\rangle
    $$

    where $|\\alpha|^2 + |\\beta|^2 = 1$.

    ## Key Principles

    - **Superposition**: A qubit exists in multiple states simultaneously
    - **Entanglement**: Qubits can be correlated regardless of distance
    - **Interference**: Quantum states can amplify or cancel each other

    ## Quantum Gates

    ```
    Hadamard Gate (H):     Pauli-X Gate:      CNOT Gate:
    |0⟩ → (|0⟩+|1⟩)/√2    |0⟩ → |1⟩          |00⟩ → |00⟩
    |1⟩ → (|0⟩-|1⟩)/√2    |1⟩ → |0⟩          |01⟩ → |01⟩
                                               |10⟩ → |11⟩
                                               |11⟩ → |10⟩
    ```

    ## Quantum vs Classical

    | Property | Classical | Quantum |
    |----------|-----------|---------|
    | Unit | Bit (0/1) | Qubit (superposition) |
    | Operations | Logic gates | Quantum gates |
    | Parallelism | Sequential | Exponential |
    | Error rate | Very low | High (needs correction) |
    | Best for | General compute | Optimization, simulation |

    > **Quantum advantage** occurs when a quantum computer solves a problem faster than any classical computer could. Google claimed this in 2019 with their Sycamore processor.

    ---

    Quantum computing is still in its **NISQ era** (Noisy Intermediate-Scale Quantum), meaning current devices have limited qubits and high error rates.
    """

    static let compilerResponse = """
    # How Compilers Work

    A compiler translates **source code** into **machine code** through several phases.

    ## Compilation Pipeline

    ```
    Source Code → Lexer → Parser → AST → Semantic Analysis
        → IR Generation → Optimization → Code Generation → Binary
    ```

    ## 1. Lexical Analysis (Lexer)

    Breaks source text into tokens:

    ```swift
    // Input: "let x = 42 + y"
    // Tokens:
    [.keyword("let"), .identifier("x"), .equals,
     .intLiteral(42), .plus, .identifier("y")]
    ```

    ## 2. Parsing

    Builds an Abstract Syntax Tree:

    ```
          LetDecl
         /       \\
     name:"x"   BinaryExpr(+)
                /           \\
           IntLit(42)    Ident("y")
    ```

    ## 3. Semantic Analysis

    - **Type checking**: Is `42 + y` valid?
    - **Name resolution**: What does `y` refer to?
    - **Scope analysis**: Is `x` accessible here?

    ## 4. IR & Optimization

    ```llvm
    define i64 @add(i64 %x, i64 %y) {
      %result = add i64 %x, %y
      ret i64 %result
    }
    ```

    Common optimizations:
    - **Dead code elimination**
    - **Constant folding**: `3 + 4` becomes `7`
    - **Loop unrolling**
    - **Inlining**: Replace function call with body
    - **Register allocation**

    > Modern compilers like **LLVM** use SSA (Static Single Assignment) form as their intermediate representation, enabling powerful optimizations.

    ---

    The entire Swift compilation pipeline: **Swift Source** → **SIL** (Swift Intermediate Language) → **LLVM IR** → **Machine Code**.
    """

    static let waterCycleResponse = """
    # The Water Cycle

    The water cycle (hydrological cycle) describes the continuous movement of water on, above, and below Earth's surface.

    ## Stages

    1. **Evaporation** — Water from oceans, lakes, and rivers converts to vapor
    2. **Transpiration** — Plants release water vapor through their leaves
    3. **Condensation** — Water vapor cools and forms clouds
    4. **Precipitation** — Water falls as rain, snow, sleet, or hail
    5. **Collection** — Water gathers in oceans, rivers, lakes, and groundwater

    ## Key Numbers

    | Reservoir | Volume (km cubed) | Percentage |
    |-----------|:-:|:-:|
    | Oceans | 1,338,000,000 | 96.5% |
    | Ice caps | 24,064,000 | 1.74% |
    | Groundwater | 23,400,000 | 1.69% |
    | Fresh surface | 93,100 | 0.007% |
    | Atmosphere | 12,900 | 0.001% |

    > Only about **0.3%** of Earth's water is fresh and accessible for human use.

    ## Cycle Duration

    - Ocean to atmosphere: ~3,000 years average residence
    - Atmosphere: ~9 days
    - Rivers: ~2 weeks
    - Glaciers: 20-100 years
    - Deep groundwater: 10,000+ years

    ---

    Climate change is accelerating the water cycle, causing more **intense** precipitation events and longer **drought** periods.
    """
}

// MARK: - Models

struct ChatMsg: Identifiable {
    let id = UUID()
    let role: ChatMessageConfiguration.Role
    let text: String
    var renderer: StreamingMarkdownRenderer?
}

// MARK: - Dark theme for assistant messages on dark background

private let darkAssistantTheme = MarkdownTheme(
    bodyFont: .system(size: 15),
    foregroundColor: Color(white: 0.88),
    paragraphSpacing: 10,
    blockSpacing: 10,
    codeBlock: CodeBlockStyle(
        backgroundColor: Color(white: 0.1),
        textColor: Color(white: 0.82),
        font: .system(size: 12.5, design: .monospaced),
        cornerRadius: 10,
        padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
    ),
    inlineCode: InlineCodeStyle(
        backgroundColor: Color(white: 0.15),
        textColor: Color(red: 0.95, green: 0.7, blue: 0.5),
        font: .system(size: 13, design: .monospaced),
        cornerRadius: 4,
        horizontalPadding: 5,
        verticalPadding: 2
    ),
    blockquote: BlockquoteStyle(
        borderColor: Color(white: 0.3),
        borderWidth: 2,
        textColor: Color(white: 0.6)
    ),
    table: TableStyle(
        borderStyle: .solid(color: Color(white: 0.2), width: 0.5),
        headerBackground: Color(white: 0.1),
        headerFontWeight: .semibold,
        backgroundStyle: .alternatingRows(
            even: Color(white: 0.06),
            odd: .clear
        )
    ),
    thematicBreak: ThematicBreakStyle(
        color: Color(white: 0.2),
        height: 0.5,
        verticalPadding: 16
    ),
    link: LinkStyle(color: Color(red: 0.45, green: 0.68, blue: 1.0)),
    citation: CitationStyle(
        fontSize: 11,
        textColor: Color(white: 0.5),
        backgroundColor: Color(white: 0.12),
        cornerRadius: 9
    )
)

// MARK: - Shared highlighter (reused across all messages)

@MainActor
private let sharedHighlighter = HighlightrCodeSyntaxHighlighter(theme: "atom-one-dark")

// MARK: - Message Row

struct MessageRow: View {
    let message: ChatMsg

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.role == .user {
                HStack {
                    Spacer(minLength: 80)
                    SwiftUI.Text(message.text)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let renderer = message.renderer {
                        StreamingMarkdownContentView(renderer: renderer)
                            .markdownTheme(darkAssistantTheme)
                            .codeSyntaxHighlighter(sharedHighlighter)
                            .tokenReveal(.init(duration: 0.15))
                    } else {
                        MarkdownView(message.text, processors: [
                            AutoLinkTransformer(),
                            LatexTransformer(),
                            CitationProcessor(),
                        ])
                        .markdownTheme(darkAssistantTheme)
                        .codeSyntaxHighlighter(sharedHighlighter)
                        .tokenReveal(.disabled)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Rectangle()
                .fill(Color(white: 0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
    }
}
