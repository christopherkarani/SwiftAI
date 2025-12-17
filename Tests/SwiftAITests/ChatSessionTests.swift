// ChatSessionTests.swift
// SwiftAITests

import Testing
@testable import SwiftAI

// MARK: - Mock Provider

/// A mock provider for testing ChatSession behavior.
///
/// Uses `@preconcurrency` to handle the actor isolation requirements
/// for conforming to `TextGenerator` protocol.
actor MockTextProvider: AIProvider, @preconcurrency TextGenerator {
    typealias Response = GenerationResult
    typealias StreamChunk = GenerationChunk
    typealias ModelID = ModelIdentifier

    // MARK: - Mock Configuration

    /// The response text to return from generate calls.
    private var _responseToReturn: String = "Mock response"

    /// Whether to throw an error on generate calls.
    private var _shouldThrowError: Bool = false

    /// Messages received in the last generate call.
    private var _lastReceivedMessages: [Message] = []

    /// Number of times generate was called.
    private var _generateCallCount: Int = 0

    // MARK: - Accessors for Test Assertions

    var responseToReturn: String {
        get { _responseToReturn }
        set { _responseToReturn = newValue }
    }

    var shouldThrowError: Bool {
        get { _shouldThrowError }
        set { _shouldThrowError = newValue }
    }

    var lastReceivedMessages: [Message] {
        get { _lastReceivedMessages }
        set { _lastReceivedMessages = newValue }
    }

    var generateCallCount: Int {
        get { _generateCallCount }
        set { _generateCallCount = newValue }
    }

    // MARK: - AIProvider

    var isAvailable: Bool { true }

    var availabilityStatus: ProviderAvailability {
        .available
    }

    func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        _generateCallCount += 1
        _lastReceivedMessages = messages

        if _shouldThrowError {
            throw MockError.simulatedFailure
        }

        return GenerationResult(
            text: _responseToReturn,
            tokenCount: _responseToReturn.split(separator: " ").count,
            generationTime: 0.5,
            tokensPerSecond: 20.0,
            finishReason: .stop
        )
    }

    func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        _lastReceivedMessages = messages
        let responseText = _responseToReturn
        let throwError = _shouldThrowError

        return AsyncThrowingStream { continuation in
            if throwError {
                continuation.finish(throwing: MockError.simulatedFailure)
                return
            }

            let words = responseText.split(separator: " ")
            Task {
                for (index, word) in words.enumerated() {
                    let isLast = index == words.count - 1
                    let chunk = GenerationChunk(
                        text: String(word) + (isLast ? "" : " "),
                        tokenCount: 1,
                        isComplete: isLast,
                        finishReason: isLast ? .stop : nil
                    )
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    func cancelGeneration() async {
        // No-op for tests
    }

    // MARK: - TextGenerator Protocol Methods

    nonisolated func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }

    nonisolated func stream(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let textStream = await self.stream(messages: [Message.user(prompt)], model: model, config: config)
                do {
                    for try await chunk in textStream {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let textStream = await self.stream(messages: messages, model: model, config: config)
                do {
                    for try await chunk in textStream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Reset

    func reset() {
        _responseToReturn = "Mock response"
        _shouldThrowError = false
        _lastReceivedMessages = []
        _generateCallCount = 0
    }
}

/// Errors for mock testing.
enum MockError: Error {
    case simulatedFailure
}

// MARK: - ChatSession Tests

@Suite("ChatSession Tests")
struct ChatSessionTests {

    @Test("Initialization sets default values")
    func initialization() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        #expect(session.messages.isEmpty)
        #expect(session.isGenerating == false)
        #expect(session.lastError == nil)
    }

    @Test("Initialization with custom config")
    func initializationWithConfig() async {
        let provider = MockTextProvider()
        let config = GenerateConfig.creative
        let session = ChatSession(provider: provider, model: .llama3_2_1B, config: config)

        #expect(session.config.temperature == config.temperature)
    }

    // MARK: - System Prompt Tests

    @Test("setSystemPrompt adds system message at beginning")
    func setSystemPromptAddsMessage() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("You are helpful.")

        #expect(session.messages.count == 1)
        #expect(session.messages[0].role == .system)
        #expect(session.messages[0].content.textValue == "You are helpful.")
    }

    @Test("setSystemPrompt replaces existing system message")
    func setSystemPromptReplacesExisting() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("First prompt")
        session.setSystemPrompt("Second prompt")

        #expect(session.messages.count == 1)
        #expect(session.messages[0].content.textValue == "Second prompt")
    }

    @Test("hasSystemPrompt returns correct value")
    func hasSystemPromptProperty() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        #expect(session.hasSystemPrompt == false)

        session.setSystemPrompt("Test")

        #expect(session.hasSystemPrompt == true)
    }

    @Test("systemPrompt property returns current prompt")
    func systemPromptProperty() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        #expect(session.systemPrompt == nil)

        session.setSystemPrompt("Test prompt")

        #expect(session.systemPrompt == "Test prompt")
    }

    // MARK: - Send Tests

    @Test("send adds user and assistant messages")
    func sendAddsMessages() async throws {
        let provider = MockTextProvider()
        await provider.reset()

        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        let response = try await session.send("Hello")

        #expect(response == "Mock response")
        #expect(session.messages.count == 2)
        #expect(session.messages[0].role == .user)
        #expect(session.messages[0].content.textValue == "Hello")
        #expect(session.messages[1].role == .assistant)
        #expect(session.messages[1].content.textValue == "Mock response")
    }

    @Test("send passes all messages to provider")
    func sendPassesAllMessages() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("System")
        _ = try await session.send("User message")

        let received = await provider.lastReceivedMessages

        #expect(received.count == 2)
        #expect(received[0].role == .system)
        #expect(received[1].role == .user)
    }

    // MARK: - Clear History Tests

    @Test("clearHistory removes all messages except system")
    func clearHistoryPreservesSystem() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("System prompt")
        _ = try await session.send("Hello")

        session.clearHistory()

        #expect(session.messages.count == 1)
        #expect(session.messages[0].role == .system)
    }

    @Test("clearHistory with no system prompt results in empty array")
    func clearHistoryNoSystem() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        _ = try await session.send("Hello")

        session.clearHistory()

        #expect(session.messages.isEmpty)
    }

    // MARK: - Undo Tests

    @Test("undoLastExchange removes last user-assistant pair")
    func undoLastExchange() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("System")
        _ = try await session.send("First question")
        _ = try await session.send("Second question")

        // Should have: system + 2x(user + assistant) = 5 messages
        #expect(session.messages.count == 5)

        session.undoLastExchange()

        // Should have: system + 1x(user + assistant) = 3 messages
        #expect(session.messages.count == 3)
        #expect(session.messages.last?.content.textValue == "Mock response")
    }

    @Test("undoLastExchange on empty history does nothing")
    func undoLastExchangeEmpty() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.undoLastExchange()

        #expect(session.messages.isEmpty)
    }

    // MARK: - Inject History Tests

    @Test("injectHistory adds messages while preserving system prompt")
    func injectHistoryPreservesSystem() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("System")

        let history: [Message] = [
            .user("Previous question"),
            .assistant("Previous answer")
        ]

        session.injectHistory(history)

        #expect(session.messages.count == 3)
        #expect(session.messages[0].role == .system)
        #expect(session.messages[1].role == .user)
        #expect(session.messages[2].role == .assistant)
    }

    @Test("injectHistory filters out system messages from injected history")
    func injectHistoryFiltersSystem() async {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        session.setSystemPrompt("Current system")

        let history: [Message] = [
            .system("Old system"),  // Should be filtered out
            .user("Question"),
            .assistant("Answer")
        ]

        session.injectHistory(history)

        #expect(session.messages.count == 3)
        #expect(session.messages[0].content.textValue == "Current system")
    }

    // MARK: - Computed Properties Tests

    @Test("messageCount returns total message count")
    func messageCountProperty() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        #expect(session.messageCount == 0)

        session.setSystemPrompt("System")
        _ = try await session.send("Hello")

        #expect(session.messageCount == 3)
    }

    @Test("userMessageCount returns only user messages")
    func userMessageCountProperty() async throws {
        let provider = MockTextProvider()
        let session = ChatSession(provider: provider, model: .llama3_2_1B)

        #expect(session.userMessageCount == 0)

        session.setSystemPrompt("System")
        _ = try await session.send("Hello")
        _ = try await session.send("World")

        #expect(session.userMessageCount == 2)
    }
}
