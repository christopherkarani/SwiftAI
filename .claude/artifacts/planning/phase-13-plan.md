# Phase 13: Result Builders & Convenience APIs

## Objective

Implement result builders and convenience extensions that enable declarative, fluent APIs for message construction, prompt building, and common operations. This phase transforms SwiftAI from a functional SDK into an ergonomic, Swift-idiomatic framework.

## Prerequisites

- [x] Phase 1-12 complete (Core types, Protocols, Providers)
- [x] Message type fully implemented with factory methods
- [x] GenerateConfig with fluent API complete
- [x] GenerationStream and GenerationResult implemented
- [x] AIProvider, EmbeddingGenerator, Transcriber protocols defined
- [x] TokenCounterExtensions complete
- [x] IntContextExtensions complete

---

## Implementation Order

The tasks are ordered by dependencies. Tasks within the same group can be parallelized.

```
Group 1 (Parallel):
  Task 1: MessageBuilder
  Task 2: PromptBuilder

Group 2 (Depends on Group 1):
  Task 3: ChatSession

Group 3 (Parallel, Independent):
  Task 4: StringExtensions
  Task 5: ArrayExtensions
  Task 6: URLExtensions
```

---

## Tasks

### Task 1: MessageBuilder Result Builder

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Builders/MessageBuilder.swift`

**Dependencies**: Message type (complete)

**Parallelizable**: Yes (with Task 2)

**Estimated Complexity**: Medium

#### Description

Implement a `@resultBuilder` struct that enables declarative message construction with support for conditionals, loops, and optional messages.

#### Code Signatures

```swift
// MARK: - MessageBuilder

/// A result builder for declaratively constructing message arrays.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     Message.system("You are a helpful assistant.")
///     Message.user("Hello!")
///
///     if includeContext {
///         Message.user("Context: \(context)")
///     }
///
///     for example in examples {
///         Message.user(example.question)
///         Message.assistant(example.answer)
///     }
/// }
/// ```
@resultBuilder
public struct MessageBuilder {

    // MARK: - Core Building Blocks

    /// Builds a single message expression.
    public static func buildExpression(_ expression: Message) -> [Message]

    /// Builds an optional message expression.
    public static func buildExpression(_ expression: Message?) -> [Message]

    /// Builds an array of messages expression.
    public static func buildExpression(_ expression: [Message]) -> [Message]

    /// Combines multiple message arrays into one.
    public static func buildBlock(_ components: [Message]...) -> [Message]

    /// Builds an empty block (no messages).
    public static func buildBlock() -> [Message]

    // MARK: - Conditional Support

    /// Handles the `if` branch without an `else`.
    public static func buildOptional(_ component: [Message]?) -> [Message]

    /// Handles the `if` branch of an `if-else`.
    public static func buildEither(first component: [Message]) -> [Message]

    /// Handles the `else` branch of an `if-else`.
    public static func buildEither(second component: [Message]) -> [Message]

    // MARK: - Loop Support

    /// Handles `for-in` loops.
    public static func buildArray(_ components: [[Message]]) -> [Message]

    // MARK: - Availability & Limited Availability

    /// Supports `#available` checks.
    public static func buildLimitedAvailability(_ component: [Message]) -> [Message]

    // MARK: - Final Result

    /// Produces the final result.
    public static func buildFinalResult(_ component: [Message]) -> [Message]
}

// MARK: - Convenience Function

/// Creates an array of messages using declarative syntax.
///
/// ## Usage
/// ```swift
/// let conversation = Messages {
///     Message.system("You are helpful.")
///     Message.user("What is Swift?")
/// }
/// ```
///
/// - Parameter builder: A closure that builds the messages.
/// - Returns: An array of messages.
public func Messages(@MessageBuilder _ builder: () -> [Message]) -> [Message]

/// Creates an async array of messages (for dynamic content).
public func Messages(@MessageBuilder _ builder: () async -> [Message]) async -> [Message]
```

#### Implementation Details

1. All `buildExpression` methods convert inputs to `[Message]`
2. `buildBlock` uses `flatMap` to combine component arrays
3. `buildOptional` returns empty array for `nil`
4. `buildEither` returns the component as-is (already `[Message]`)
5. `buildArray` flattens the nested arrays from loops

#### Acceptance Criteria

- [ ] `@MessageBuilder` attribute compiles without errors
- [ ] Single message expressions work: `Message.user("Hello")`
- [ ] Optional messages work: `if condition { Message.user("X") }`
- [ ] If-else works: `if cond { msg1 } else { msg2 }`
- [ ] For-in loops work: `for item in items { Message.user(item) }`
- [ ] Empty blocks compile: `Messages { }`
- [ ] Nested conditionals work
- [ ] `Messages { }` convenience function works
- [ ] Documentation complete with examples
- [ ] Unit tests pass

---

### Task 2: PromptBuilder Result Builder

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Builders/PromptBuilder.swift`

**Dependencies**: Message type (complete)

**Parallelizable**: Yes (with Task 1)

**Estimated Complexity**: Medium-High

#### Description

Implement a prompt building system with composable components that can be rendered to strings or converted to messages. Supports system instructions, user queries, context injection, and few-shot examples.

#### Code Signatures

```swift
// MARK: - PromptComponent Protocol

/// A component that can be rendered as part of a prompt.
///
/// Conforming types represent different parts of a prompt that can be
/// composed together using the `@PromptBuilder` result builder.
public protocol PromptComponent: Sendable {
    /// Renders this component to a string.
    func render() -> String
}

// MARK: - Built-in Components

/// A system instruction component.
///
/// ## Usage
/// ```swift
/// Prompt {
///     SystemInstruction("You are a helpful coding assistant.")
/// }
/// ```
public struct SystemInstruction: PromptComponent {
    public let instruction: String

    public init(_ instruction: String)
    public func render() -> String
}

/// A user query component.
///
/// ## Usage
/// ```swift
/// Prompt {
///     UserQuery("Explain async/await in Swift")
/// }
/// ```
public struct UserQuery: PromptComponent {
    public let query: String

    public init(_ query: String)
    public func render() -> String
}

/// A context component for injecting relevant information.
///
/// ## Usage
/// ```swift
/// Prompt {
///     Context(documents.map(\.content))
///     UserQuery("Summarize the above documents")
/// }
/// ```
public struct Context: PromptComponent {
    public let items: [String]
    public let separator: String
    public let prefix: String?
    public let suffix: String?

    public init(_ items: [String], separator: String = "\n\n", prefix: String? = nil, suffix: String? = nil)
    public init(_ text: String)
    public func render() -> String
}

/// A few-shot examples component.
///
/// ## Usage
/// ```swift
/// Prompt {
///     Examples([
///         Example(input: "What is 2+2?", output: "4"),
///         Example(input: "What is 3+3?", output: "6")
///     ])
///     UserQuery("What is 4+4?")
/// }
/// ```
public struct Examples: PromptComponent {
    public let examples: [Example]

    public struct Example: Sendable {
        public let input: String
        public let output: String

        public init(input: String, output: String)
    }

    public init(_ examples: [Example])
    public init(_ examples: Example...)
    public func render() -> String
}

/// A raw text component.
///
/// ## Usage
/// ```swift
/// Prompt {
///     RawText("Some custom text")
/// }
/// ```
public struct RawText: PromptComponent {
    public let text: String

    public init(_ text: String)
    public func render() -> String
}

/// A conditional component wrapper.
public struct ConditionalComponent: PromptComponent {
    private let component: (any PromptComponent)?

    public init(_ component: (any PromptComponent)?)
    public func render() -> String
}

// MARK: - PromptContent

/// The result of building a prompt with components.
///
/// Contains the rendered components and provides conversion utilities.
public struct PromptContent: Sendable {
    /// The rendered prompt string.
    public let text: String

    /// The components that make up this prompt.
    public let components: [any PromptComponent]

    /// Converts the prompt to a message array for chat models.
    ///
    /// ## Conversion Rules
    /// - `SystemInstruction` becomes `Message.system`
    /// - `UserQuery` becomes `Message.user`
    /// - `Context`, `Examples`, `RawText` become `Message.user`
    /// - Adjacent user components are combined
    ///
    /// - Returns: An array of messages.
    public func toMessages() -> [Message]

    /// Returns the prompt as a single user message.
    public func toSingleMessage() -> Message
}

// MARK: - PromptBuilder

/// A result builder for declaratively constructing prompts.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a helpful assistant.")
///
///     if hasContext {
///         Context(relevantDocs)
///     }
///
///     for example in fewShotExamples {
///         Examples(example)
///     }
///
///     UserQuery(userInput)
/// }
///
/// // Use as string
/// print(prompt.text)
///
/// // Convert to messages
/// let messages = prompt.toMessages()
/// ```
@resultBuilder
public struct PromptBuilder {

    // MARK: - Expression Building

    public static func buildExpression<C: PromptComponent>(_ expression: C) -> [any PromptComponent]
    public static func buildExpression(_ expression: (any PromptComponent)?) -> [any PromptComponent]
    public static func buildExpression(_ expression: String) -> [any PromptComponent]

    // MARK: - Block Building

    public static func buildBlock(_ components: [any PromptComponent]...) -> [any PromptComponent]
    public static func buildBlock() -> [any PromptComponent]

    // MARK: - Conditionals

    public static func buildOptional(_ component: [any PromptComponent]?) -> [any PromptComponent]
    public static func buildEither(first component: [any PromptComponent]) -> [any PromptComponent]
    public static func buildEither(second component: [any PromptComponent]) -> [any PromptComponent]

    // MARK: - Loops

    public static func buildArray(_ components: [[any PromptComponent]]) -> [any PromptComponent]

    // MARK: - Final Result

    public static func buildFinalResult(_ components: [any PromptComponent]) -> PromptContent
}

// MARK: - Convenience Function

/// Creates prompt content using declarative syntax.
///
/// - Parameter builder: A closure that builds the prompt components.
/// - Returns: A `PromptContent` instance with the rendered prompt.
public func Prompt(@PromptBuilder _ builder: () -> PromptContent) -> PromptContent
```

#### Implementation Details

1. Each component implements `render()` with appropriate formatting
2. `SystemInstruction.render()` returns instruction as-is
3. `Context.render()` joins items with separator, adds prefix/suffix
4. `Examples.render()` formats as "Input: X\nOutput: Y" pairs
5. `PromptContent.toMessages()` groups components by type

#### Acceptance Criteria

- [ ] `PromptComponent` protocol defined
- [ ] All built-in components implemented (SystemInstruction, UserQuery, Context, Examples, RawText)
- [ ] `@PromptBuilder` compiles without errors
- [ ] Conditionals work in prompt building
- [ ] For-in loops work
- [ ] `PromptContent.toMessages()` correctly converts to messages
- [ ] `Prompt { }` convenience function works
- [ ] Documentation complete with examples
- [ ] Unit tests pass

---

### Task 3: ChatSession Observable Class

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/ChatSession.swift`

**Dependencies**: Tasks 1-2 (can use MessageBuilder), AIProvider protocol

**Parallelizable**: No (depends on result builders for best UX)

**Estimated Complexity**: High

#### Description

Implement an `@Observable` class that manages conversation state with a provider. Must be thread-safe using `NSLock` or similar for state mutations. Supports streaming, history management, and cancellation.

#### Code Signatures

```swift
import Foundation
import Observation

// MARK: - ChatSession

/// An observable chat session that manages conversation state.
///
/// `ChatSession` provides a high-level interface for managing multi-turn
/// conversations with any AI provider. It handles message history, streaming,
/// and state management automatically.
///
/// ## Thread Safety
///
/// All state mutations are protected by internal locking. The class is designed
/// to be used from the main actor in SwiftUI applications.
///
/// ## Usage
///
/// ### Basic Usage
/// ```swift
/// let session = ChatSession(provider: mlxProvider, model: .llama3_2_1B)
///
/// // Set system prompt
/// await session.setSystemPrompt("You are a helpful assistant.")
///
/// // Send messages
/// let response = try await session.send("Hello!")
/// print(response.text)
/// ```
///
/// ### SwiftUI Integration
/// ```swift
/// struct ChatView: View {
///     @State private var session = ChatSession(provider: mlxProvider, model: .llama3_2_1B)
///     @State private var input = ""
///
///     var body: some View {
///         VStack {
///             ScrollView {
///                 ForEach(session.messages) { message in
///                     MessageRow(message: message)
///                 }
///             }
///
///             HStack {
///                 TextField("Message", text: $input)
///                 Button("Send") {
///                     Task {
///                         try await session.send(input)
///                         input = ""
///                     }
///                 }
///                 .disabled(session.isGenerating)
///             }
///         }
///     }
/// }
/// ```
///
/// ### Streaming
/// ```swift
/// let stream = session.stream("Tell me a story")
/// for try await chunk in stream {
///     print(chunk.text, terminator: "")
/// }
/// ```
@Observable
@MainActor
public final class ChatSession<Provider: AIProvider> {

    // MARK: - Public Properties

    /// The AI provider used for generation.
    public let provider: Provider

    /// The model identifier for generation.
    public private(set) var model: Provider.ModelID

    /// The conversation message history.
    ///
    /// Includes system messages, user messages, and assistant responses.
    /// This array is updated automatically after successful generations.
    public private(set) var messages: [Message]

    /// Whether generation is currently in progress.
    ///
    /// Use this to disable UI elements during generation.
    public private(set) var isGenerating: Bool

    /// The generation configuration.
    ///
    /// Modify this to change sampling parameters for future generations.
    public var config: GenerateConfig

    /// The last error that occurred during generation.
    ///
    /// Reset to `nil` before each new generation attempt.
    public private(set) var lastError: Error?

    /// The current streaming text (partial response).
    ///
    /// Updated incrementally during streaming generation.
    /// Reset to empty string when streaming completes.
    public private(set) var streamingText: String

    // MARK: - Private Properties

    /// Lock for thread-safe state mutations.
    private let lock = NSLock()

    /// The current generation task (for cancellation).
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new chat session.
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use for generation.
    ///   - model: The model identifier for generation.
    ///   - config: Generation configuration (defaults to `.default`).
    ///   - systemPrompt: Optional initial system prompt.
    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default,
        systemPrompt: String? = nil
    )

    // MARK: - System Prompt

    /// Sets or updates the system prompt.
    ///
    /// If a system prompt already exists, it is replaced.
    /// If `nil` is passed, any existing system prompt is removed.
    ///
    /// - Parameter prompt: The system prompt text, or `nil` to remove.
    public func setSystemPrompt(_ prompt: String?)

    // MARK: - Message Sending

    /// Sends a user message and waits for the complete response.
    ///
    /// This method:
    /// 1. Adds the user message to history
    /// 2. Generates a response from the provider
    /// 3. Adds the assistant response to history
    /// 4. Returns the generation result
    ///
    /// - Parameter text: The user message text.
    /// - Returns: The generation result containing the assistant's response.
    /// - Throws: `AIError` if generation fails.
    @discardableResult
    public func send(_ text: String) async throws -> Provider.Response

    /// Sends messages built with the message builder.
    ///
    /// - Parameter builder: A closure that builds additional messages.
    /// - Returns: The generation result.
    /// - Throws: `AIError` if generation fails.
    @discardableResult
    public func send(@MessageBuilder _ builder: () -> [Message]) async throws -> Provider.Response

    // MARK: - Streaming

    /// Streams a response for the given user message.
    ///
    /// The user message is added to history immediately. The assistant's
    /// response is built incrementally and added to history when complete.
    ///
    /// The `streamingText` property is updated as chunks arrive.
    ///
    /// - Parameter text: The user message text.
    /// - Returns: A stream of generation chunks.
    public func stream(_ text: String) -> AsyncThrowingStream<Provider.StreamChunk, Error>

    /// Streams messages built with the message builder.
    ///
    /// - Parameter builder: A closure that builds additional messages.
    /// - Returns: A stream of generation chunks.
    public func stream(@MessageBuilder _ builder: () -> [Message]) -> AsyncThrowingStream<Provider.StreamChunk, Error>

    // MARK: - History Management

    /// Clears all messages from the conversation history.
    ///
    /// System prompts are preserved by default.
    ///
    /// - Parameter preserveSystemPrompt: Whether to keep the system prompt.
    public func clearHistory(preserveSystemPrompt: Bool = true)

    /// Removes the last user message and assistant response pair.
    ///
    /// Useful for implementing "undo" or "regenerate" functionality.
    ///
    /// - Returns: `true` if messages were removed, `false` if history was empty.
    @discardableResult
    public func undoLastExchange() -> Bool

    /// Injects messages into the conversation history.
    ///
    /// Use this to restore a previous conversation or inject context.
    ///
    /// - Parameters:
    ///   - messages: The messages to inject.
    ///   - position: Where to insert (defaults to end).
    public func injectHistory(_ messages: [Message], at position: Int? = nil)

    /// Injects messages using the builder syntax.
    ///
    /// - Parameter builder: A closure that builds messages to inject.
    public func injectHistory(@MessageBuilder _ builder: () -> [Message])

    // MARK: - Cancellation

    /// Cancels the current generation if one is in progress.
    ///
    /// After cancellation:
    /// - `isGenerating` becomes `false`
    /// - Partial streaming text is preserved in `streamingText`
    /// - The incomplete response is NOT added to history
    public func cancel()

    // MARK: - Model Switching

    /// Changes the model used for future generations.
    ///
    /// Does not affect the conversation history.
    ///
    /// - Parameter model: The new model identifier.
    public func setModel(_ model: Provider.ModelID)

    // MARK: - Convenience Properties

    /// The total number of messages in history.
    public var messageCount: Int { get }

    /// Whether the conversation has any messages beyond system prompts.
    public var hasConversation: Bool { get }

    /// The last assistant message, if any.
    public var lastAssistantMessage: Message? { get }

    /// The last user message, if any.
    public var lastUserMessage: Message? { get }
}

// MARK: - ChatSession State Helpers

extension ChatSession {

    /// Thread-safe state mutation helper.
    private func withLock<T>(_ operation: () -> T) -> T

    /// Updates isGenerating state safely.
    private func setGenerating(_ value: Bool)

    /// Updates error state safely.
    private func setError(_ error: Error?)

    /// Updates streaming text safely.
    private func appendStreamingText(_ text: String)

    /// Resets streaming state for new generation.
    private func resetStreamingState()
}
```

#### Thread Safety Implementation

```swift
// Example of thread-safe state mutation pattern:
private func withLock<T>(_ operation: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return operation()
}

// Usage in methods:
public func send(_ text: String) async throws -> Provider.Response {
    guard !withLock({ isGenerating }) else {
        throw AIError.operationInProgress
    }

    withLock {
        isGenerating = true
        lastError = nil
        messages.append(.user(text))
    }

    defer {
        withLock { isGenerating = false }
    }

    // ... generation logic
}
```

#### Acceptance Criteria

- [ ] `@Observable` class compiles without errors
- [ ] Thread safety implemented with `NSLock`
- [ ] `setSystemPrompt` works correctly
- [ ] `send(_:)` adds messages and generates response
- [ ] `stream(_:)` returns working stream and updates `streamingText`
- [ ] `clearHistory` works with and without preserving system prompt
- [ ] `undoLastExchange` removes correct message pairs
- [ ] `injectHistory` works at specified positions
- [ ] `cancel()` stops generation and updates state
- [ ] `MessageBuilder` integration works for `send` and `injectHistory`
- [ ] SwiftUI integration tested (builds and observes correctly)
- [ ] Documentation complete with examples
- [ ] Unit tests pass

---

### Task 4: String Extensions

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Extensions/StringExtensions.swift`

**Dependencies**: AIProvider, EmbeddingGenerator, TokenCounter protocols

**Parallelizable**: Yes (with Tasks 5, 6)

**Estimated Complexity**: Low-Medium

#### Description

Add convenience methods to `String` that allow direct generation, streaming, embedding, and token counting without explicitly creating messages.

#### Code Signatures

```swift
// MARK: - String Generation Extensions

extension String {

    /// Generates a response for this string using the specified provider.
    ///
    /// This is a convenience method that wraps the string in a user message
    /// and calls the provider's generate method.
    ///
    /// ## Usage
    /// ```swift
    /// let response = try await "What is Swift?"
    ///     .generate(with: mlxProvider, model: .llama3_2_1B)
    /// print(response.text)
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use.
    ///   - model: The model identifier.
    ///   - config: Generation configuration (defaults to `.default`).
    /// - Returns: The generation result.
    /// - Throws: `AIError` if generation fails.
    public func generate<P: AIProvider>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> P.Response

    /// Streams a response for this string using the specified provider.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = "Tell me a story".stream(with: mlxProvider, model: .llama3_2_1B)
    /// for try await chunk in stream {
    ///     print(chunk.text, terminator: "")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use.
    ///   - model: The model identifier.
    ///   - config: Generation configuration (defaults to `.default`).
    /// - Returns: A stream of generation chunks.
    public func stream<P: AIProvider>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<P.StreamChunk, Error>
}

// MARK: - String Embedding Extensions

extension String {

    /// Generates an embedding for this string.
    ///
    /// ## Usage
    /// ```swift
    /// let embedding = try await "SwiftAI is great".embed(with: mlxProvider, model: .bgeSmall)
    /// print("Dimensions: \(embedding.dimensions)")
    /// ```
    ///
    /// - Parameters:
    ///   - provider: An embedding-capable provider.
    ///   - model: The embedding model identifier.
    /// - Returns: The embedding result.
    /// - Throws: `AIError` if embedding fails.
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> EmbeddingResult
}

// MARK: - String Token Counting Extensions

extension String {

    /// Counts tokens in this string for the specified model.
    ///
    /// ## Usage
    /// ```swift
    /// let count = try await longText.tokenCount(with: mlxProvider, model: .llama3_2_1B)
    /// print("Token count: \(count)")
    /// ```
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    /// - Returns: The number of tokens.
    /// - Throws: `AIError` if counting fails.
    public func tokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int

    /// Gets detailed token information for this string.
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    /// - Returns: Detailed token count information.
    /// - Throws: `AIError` if counting fails.
    public func tokens<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> TokenCount

    /// Checks if this string fits within a context window.
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    ///   - contextSize: The context window size (use `Int.context8K`, etc.).
    /// - Returns: `true` if the string fits.
    /// - Throws: `AIError` if counting fails.
    public func fitsInContext<P: TokenCounter>(
        with provider: P,
        model: P.ModelID,
        contextSize: Int
    ) async throws -> Bool
}
```

#### Implementation Details

1. `generate` wraps string in `[Message.user(self)]` and calls `provider.generate`
2. `stream` similarly wraps and calls `provider.stream`
3. `embed` calls `provider.embed(self, model:)`
4. `tokenCount` calls `provider.countTokens(in: self, for:).count`
5. All methods are generic over the provider type

#### Acceptance Criteria

- [ ] `generate(with:model:config:)` works correctly
- [ ] `stream(with:model:config:)` returns valid stream
- [ ] `embed(with:model:)` produces embedding
- [ ] `tokenCount(with:model:)` returns count
- [ ] `tokens(with:model:)` returns full TokenCount
- [ ] `fitsInContext(with:model:contextSize:)` works
- [ ] All methods have documentation
- [ ] Unit tests pass

---

### Task 5: Array Extensions

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Extensions/ArrayExtensions.swift`

**Dependencies**: AIProvider, EmbeddingGenerator protocols

**Parallelizable**: Yes (with Tasks 4, 6)

**Estimated Complexity**: Low-Medium

#### Description

Add convenience methods to `[Message]` for generation and `[String]` for batch embedding.

#### Code Signatures

```swift
// MARK: - [Message] Generation Extensions

extension Array where Element == Message {

    /// Generates a response for this message array.
    ///
    /// ## Usage
    /// ```swift
    /// let messages = Messages {
    ///     Message.system("You are helpful.")
    ///     Message.user("Hello!")
    /// }
    /// let response = try await messages.generate(with: mlxProvider, model: .llama3_2_1B)
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use.
    ///   - model: The model identifier.
    ///   - config: Generation configuration.
    /// - Returns: The generation result.
    /// - Throws: `AIError` if generation fails.
    public func generate<P: AIProvider>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> P.Response

    /// Streams a response for this message array.
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use.
    ///   - model: The model identifier.
    ///   - config: Generation configuration.
    /// - Returns: A stream of generation chunks.
    public func stream<P: AIProvider>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<P.StreamChunk, Error>

    /// Counts total tokens in this message array.
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    /// - Returns: Total token count across all messages.
    /// - Throws: `AIError` if counting fails.
    public func tokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int

    /// Gets detailed token count for this message array.
    public func tokens<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> TokenCount
}

// MARK: - [String] Embedding Extensions

extension Array where Element == String {

    /// Generates embeddings for all strings in the array.
    ///
    /// Uses batch processing for efficiency when available.
    ///
    /// ## Usage
    /// ```swift
    /// let documents = ["Doc 1 content", "Doc 2 content", "Doc 3 content"]
    /// let embeddings = try await documents.embed(with: mlxProvider, model: .bgeSmall)
    /// ```
    ///
    /// - Parameters:
    ///   - provider: An embedding-capable provider.
    ///   - model: The embedding model identifier.
    /// - Returns: An array of embedding results in the same order.
    /// - Throws: `AIError` if embedding fails.
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> [EmbeddingResult]

    /// Counts tokens for all strings in the array.
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    /// - Returns: An array of token counts in the same order.
    /// - Throws: `AIError` if counting fails.
    public func tokenCounts<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> [Int]

    /// Gets total token count across all strings.
    ///
    /// - Parameters:
    ///   - provider: A token-counting capable provider.
    ///   - model: The model whose tokenizer to use.
    /// - Returns: Total token count.
    /// - Throws: `AIError` if counting fails.
    public func totalTokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int
}

// MARK: - [Message] Convenience Properties

extension Array where Element == Message {

    /// Returns only the user messages.
    public var userMessages: [Message] { get }

    /// Returns only the assistant messages.
    public var assistantMessages: [Message] { get }

    /// Returns only the system messages.
    public var systemMessages: [Message] { get }

    /// Returns the combined text content of all messages.
    public var combinedText: String { get }

    /// Returns the last user message, if any.
    public var lastUserMessage: Message? { get }

    /// Returns the last assistant message, if any.
    public var lastAssistantMessage: Message? { get }
}
```

#### Implementation Details

1. `[Message].generate` calls `provider.generate(messages:model:config:)`
2. `[String].embed` calls `provider.embedBatch` for efficiency
3. Token counting uses batch methods when available
4. Message filtering uses `filter { $0.role == .xxx }`

#### Acceptance Criteria

- [ ] `[Message].generate(with:model:config:)` works
- [ ] `[Message].stream(with:model:config:)` works
- [ ] `[Message].tokenCount(with:model:)` works
- [ ] `[String].embed(with:model:)` uses batch processing
- [ ] `[String].tokenCounts(with:model:)` works
- [ ] Convenience properties work correctly
- [ ] Documentation complete
- [ ] Unit tests pass

---

### Task 6: URL Extensions

**File**: `/Users/chriskarani/CodingProjects/SwiftAI/Sources/SwiftAI/Extensions/URLExtensions.swift`

**Dependencies**: Transcriber protocol

**Parallelizable**: Yes (with Tasks 4, 5)

**Estimated Complexity**: Low

#### Description

Add convenience methods to `URL` for audio transcription.

#### Code Signatures

```swift
// MARK: - URL Transcription Extensions

extension URL {

    /// Transcribes the audio file at this URL.
    ///
    /// ## Usage
    /// ```swift
    /// let audioURL = Bundle.main.url(forResource: "recording", withExtension: "m4a")!
    /// let result = try await audioURL.transcribe(with: hfProvider, model: .whisper)
    /// print(result.text)
    /// ```
    ///
    /// ## Supported Formats
    /// - WAV
    /// - MP3
    /// - M4A
    /// - FLAC
    ///
    /// - Parameters:
    ///   - provider: A transcription-capable provider.
    ///   - model: The transcription model identifier.
    ///   - config: Transcription configuration (defaults to `.default`).
    /// - Returns: The transcription result.
    /// - Throws: `AIError` if transcription fails.
    public func transcribe<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        config: TranscriptionConfig = .default
    ) async throws -> TranscriptionResult

    /// Streams transcription segments as they become available.
    ///
    /// ## Usage
    /// ```swift
    /// let stream = audioURL.streamTranscription(with: provider, model: .whisper)
    /// for try await segment in stream {
    ///     print("[\(segment.startTime)s]: \(segment.text)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - provider: A transcription-capable provider.
    ///   - model: The transcription model identifier.
    ///   - config: Transcription configuration.
    /// - Returns: A stream of transcription segments.
    public func streamTranscription<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        config: TranscriptionConfig = .default
    ) -> AsyncThrowingStream<TranscriptionSegment, Error>
}

// MARK: - URL Audio File Helpers

extension URL {

    /// Whether this URL points to a supported audio file format.
    ///
    /// Checks the file extension against known audio formats.
    public var isSupportedAudioFile: Bool { get }

    /// The audio file extension without the dot.
    public var audioExtension: String? { get }
}
```

#### Implementation Details

1. `transcribe` calls `provider.transcribe(audioURL:model:config:)`
2. `streamTranscription` calls `provider.streamTranscription`
3. `isSupportedAudioFile` checks against `["wav", "mp3", "m4a", "flac", "ogg", "webm"]`
4. `audioExtension` extracts and lowercases the path extension

#### Acceptance Criteria

- [ ] `transcribe(with:model:config:)` works correctly
- [ ] `streamTranscription(with:model:config:)` returns valid stream
- [ ] `isSupportedAudioFile` correctly identifies audio files
- [ ] `audioExtension` extracts extension correctly
- [ ] Documentation complete
- [ ] Unit tests pass

---

## Verification Checklist

### Compilation & Build

- [ ] `swift build` passes without errors
- [ ] `swift build` passes without warnings
- [ ] All files created in correct locations

### Test Coverage

- [ ] MessageBuilder unit tests
- [ ] PromptBuilder unit tests
- [ ] ChatSession unit tests (mock provider)
- [ ] StringExtensions unit tests
- [ ] ArrayExtensions unit tests
- [ ] URLExtensions unit tests
- [ ] Integration tests with real providers (if available)
- [ ] `swift test` passes all tests

### Documentation

- [ ] All public types have doc comments
- [ ] All public methods have doc comments with examples
- [ ] Usage examples are accurate and compile

### Code Quality

- [ ] `swiftlint lint --strict` passes
- [ ] Consistent code style with existing codebase
- [ ] No force unwraps (`!`) except in tests
- [ ] All types are `Sendable` where required
- [ ] Thread safety verified for ChatSession

---

## Test Strategy

### Unit Tests

Create test files:
- `Tests/SwiftAITests/Builders/MessageBuilderTests.swift`
- `Tests/SwiftAITests/Builders/PromptBuilderTests.swift`
- `Tests/SwiftAITests/ChatSessionTests.swift`
- `Tests/SwiftAITests/Extensions/StringExtensionsTests.swift`
- `Tests/SwiftAITests/Extensions/ArrayExtensionsTests.swift`
- `Tests/SwiftAITests/Extensions/URLExtensionsTests.swift`

### MessageBuilder Tests

```swift
func testSingleMessage() {
    let messages = Messages {
        Message.user("Hello")
    }
    XCTAssertEqual(messages.count, 1)
    XCTAssertEqual(messages[0].role, .user)
}

func testConditional() {
    let includeSystem = true
    let messages = Messages {
        if includeSystem {
            Message.system("System")
        }
        Message.user("User")
    }
    XCTAssertEqual(messages.count, 2)
}

func testLoop() {
    let questions = ["Q1", "Q2", "Q3"]
    let messages = Messages {
        for q in questions {
            Message.user(q)
        }
    }
    XCTAssertEqual(messages.count, 3)
}
```

### Mock Provider for Testing

```swift
actor MockProvider: AIProvider {
    typealias Response = GenerationResult
    typealias StreamChunk = GenerationChunk
    typealias ModelID = ModelIdentifier

    var isAvailable: Bool { true }
    var availabilityStatus: ProviderAvailability { .available }

    var generateCallCount = 0
    var lastMessages: [Message]?

    func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> Response {
        generateCallCount += 1
        lastMessages = messages
        return .text("Mock response")
    }

    func stream(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(GenerationChunk(text: "Mock", tokenCount: 1))
            continuation.yield(GenerationChunk(text: " response", tokenCount: 1, isComplete: true))
            continuation.finish()
        }
    }

    func cancelGeneration() async {}
}
```

---

## Risks & Mitigations

### Risk 1: Result Builder Complexity

**Risk**: Swift result builders have subtle semantics that can cause confusing compiler errors.

**Mitigation**:
- Implement one method at a time, testing each
- Start with `buildBlock` and `buildExpression` before conditionals
- Use descriptive error messages in documentation

### Risk 2: ChatSession Thread Safety

**Risk**: Observable + NSLock + async can create deadlocks or race conditions.

**Mitigation**:
- Always use `withLock` helper for state access
- Never hold lock across await points
- Test with concurrent access patterns
- Consider using `@MainActor` consistently

### Risk 3: Generic Type Constraints

**Risk**: Complex generic constraints on extensions may cause type inference issues.

**Mitigation**:
- Test with explicit type annotations first
- Simplify constraints if inference fails
- Provide concrete overloads for common providers if needed

### Risk 4: SwiftUI Integration

**Risk**: `@Observable` may not update SwiftUI views as expected.

**Mitigation**:
- Test with real SwiftUI preview
- Ensure mutations happen on main actor
- Use `@Published` fallback if needed for older OS versions

---

## Notes for Implementers

### Result Builder Best Practices

1. Always implement `buildBlock` first - it's the foundation
2. `buildExpression` converts single items to the component type
3. `buildOptional` handles `if` without `else`
4. `buildEither` handles `if-else` (both branches must return same type)
5. `buildArray` handles `for-in` by flattening

### ChatSession Implementation Order

1. Start with basic properties and init
2. Add `setSystemPrompt` and `clearHistory`
3. Implement `send` without streaming
4. Add streaming support
5. Implement `cancel`
6. Add history management (undo, inject)

### Testing Async Extensions

```swift
// Use expectation for async tests
func testStringGenerate() async throws {
    let provider = MockProvider()
    let result = try await "Hello".generate(with: provider, model: .llama3_2_1B)
    XCTAssertEqual(result.text, "Mock response")
}
```

---

## Deliverables Summary

| File | Status | Lines (Est.) |
|------|--------|--------------|
| `MessageBuilder.swift` | TODO | ~120 |
| `PromptBuilder.swift` | TODO | ~250 |
| `ChatSession.swift` | TODO | ~350 |
| `StringExtensions.swift` | TODO | ~100 |
| `ArrayExtensions.swift` | TODO | ~150 |
| `URLExtensions.swift` | TODO | ~80 |
| **Total** | | ~1,050 |

---

*End of Phase 13 Implementation Plan*
