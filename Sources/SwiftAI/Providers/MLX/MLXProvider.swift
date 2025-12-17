// MLXProvider.swift
// SwiftAI

import Foundation

#if arch(arm64)
@preconcurrency import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM
// Note: Tokenizer protocol is re-exported through MLXLMCommon
#endif

// MARK: - MLXProvider

/// Local inference provider using MLX on Apple Silicon.
///
/// `MLXProvider` runs language models entirely on-device using Apple's MLX framework.
/// It provides high-performance inference with complete privacy and offline capability.
///
/// ## Apple Silicon Required
///
/// MLX requires Apple Silicon (M1 or later). On Intel Macs or other platforms,
/// this provider will be unavailable.
///
/// ## Usage
///
/// ### Basic Generation
/// ```swift
/// let provider = MLXProvider()
/// let response = try await provider.generate(
///     "What is Swift?",
///     model: .llama3_2_1B,
///     config: .default
/// )
/// print(response)
/// ```
///
/// ### Streaming
/// ```swift
/// let stream = provider.stream(
///     "Write a poem",
///     model: .llama3_2_1B,
///     config: .default
/// )
/// for try await text in stream {
///     print(text, terminator: "")
/// }
/// ```
///
/// ### Token Counting
/// ```swift
/// let count = try await provider.countTokens(in: "Hello", for: .llama3_2_1B)
/// print("Tokens: \(count.count)")
/// ```
///
/// ## Protocol Conformances
/// - `AIProvider`: Core generation and streaming
/// - `TextGenerator`: Text-specific conveniences
/// - `TokenCounter`: Token counting and encoding
///
/// ## Thread Safety
/// As an actor, `MLXProvider` is thread-safe and serializes all operations.
public actor MLXProvider: AIProvider, TextGenerator, TokenCounter {

    // MARK: - Associated Types

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    // MARK: - Properties

    /// Configuration for MLX inference.
    public let configuration: MLXConfiguration

    /// Model loader for managing loaded models.
    private let modelLoader: MLXModelLoader

    /// Flag for cancellation support.
    private var isCancelled: Bool = false

    // MARK: - Initialization

    /// Creates an MLX provider with the specified configuration.
    ///
    /// - Parameter configuration: MLX configuration settings. Defaults to `.default`.
    ///
    /// ## Example
    /// ```swift
    /// // Use default configuration
    /// let provider = MLXProvider()
    ///
    /// // Use memory-efficient configuration
    /// let provider = MLXProvider(configuration: .memoryEfficient)
    ///
    /// // Custom configuration
    /// let provider = MLXProvider(
    ///     configuration: .default.memoryLimit(.gigabytes(8))
    /// )
    /// ```
    public init(configuration: MLXConfiguration = .default) {
        self.configuration = configuration
        self.modelLoader = MLXModelLoader(configuration: configuration)
    }

    // MARK: - AIProvider: Availability

    /// Whether MLX is available on this device.
    ///
    /// Returns `true` only on Apple Silicon (arm64) devices.
    public var isAvailable: Bool {
        get async {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }
    }

    /// Detailed availability status for MLX.
    ///
    /// Checks device architecture and system requirements.
    public var availabilityStatus: ProviderAvailability {
        get async {
            #if arch(arm64)
            return .available
            #else
            return .unavailable(.deviceNotSupported)
            #endif
        }
    }

    // MARK: - AIProvider: Generation

    /// Generates a complete response for the given messages.
    ///
    /// Performs non-streaming text generation and waits for the entire response
    /// before returning.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration controlling sampling and limits.
    /// - Returns: Complete generation result with metadata.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Reset cancellation flag
        isCancelled = false

        // Perform generation
        return try await performGeneration(messages: messages, model: model, config: config)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Streams generation tokens as they are produced.
    ///
    /// Returns an async stream that yields chunks incrementally during generation.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration controlling sampling and limits.
    /// - Returns: Async throwing stream of generation chunks.
    ///
    /// ## Note
    /// This method is `nonisolated` because it returns synchronously. The actual
    /// generation work happens asynchronously when the stream is iterated.
    public nonisolated func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performStreamingGeneration(
                    messages: messages,
                    model: model,
                    config: config,
                    continuation: continuation
                )
            }
        }
    }

    /// Cancels any in-flight generation request.
    ///
    /// Sets the cancellation flag to stop generation at the next opportunity.
    public func cancelGeneration() async {
        isCancelled = true
    }

    // MARK: - TextGenerator

    /// Generates text from a simple string prompt.
    ///
    /// Convenience method that wraps the prompt in a user message.
    ///
    /// - Parameters:
    ///   - prompt: Input text to generate a response for.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration.
    /// - Returns: Generated text as a string.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }

    /// Streams text generation from a simple prompt.
    ///
    /// - Parameters:
    ///   - prompt: Input text to generate a response for.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration.
    /// - Returns: Async throwing stream of text strings.
    public nonisolated func stream(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let messages = [Message.user(prompt)]
        let chunkStream = stream(messages: messages, model: model, config: config)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in chunkStream {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Streams generation with full chunk metadata.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration.
    /// - Returns: Async throwing stream of generation chunks.
    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        stream(messages: messages, model: model, config: config)
    }

    // MARK: - TokenCounter

    /// Counts tokens in the given text.
    ///
    /// - Parameters:
    ///   - text: Text to count tokens in.
    ///   - model: Model whose tokenizer to use.
    /// - Returns: Token count information.
    /// - Throws: `AIError` if tokenization fails.
    public func countTokens(
        in text: String,
        for model: ModelID
    ) async throws -> TokenCount {
        #if arch(arm64)
        // Validate model type
        guard case .mlx(let modelId) = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Encode text using model loader
        let tokens = try await modelLoader.encode(text: text, for: model)

        return TokenCount(
            count: tokens.count,
            text: text,
            tokenizer: modelId,
            tokenIds: tokens
        )
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Counts tokens in a message array, including chat template overhead.
    ///
    /// - Parameters:
    ///   - messages: Messages to count tokens in.
    ///   - model: Model whose tokenizer and chat template to use.
    /// - Returns: Token count information including special tokens.
    /// - Throws: `AIError` if tokenization fails.
    public func countTokens(
        in messages: [Message],
        for model: ModelID
    ) async throws -> TokenCount {
        #if arch(arm64)
        // Validate model type
        guard case .mlx(let modelId) = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Calculate prompt tokens (text content)
        // Note: This doesn't include chat template overhead.
        // For accurate counts with chat template, you'd need model-specific logic.
        var totalTokens = 0
        for message in messages {
            let text = message.content.textValue
            let tokens = try await modelLoader.encode(text: text, for: model)
            totalTokens += tokens.count
        }

        // Estimate special token overhead per message (role markers, etc.)
        // This is approximate - actual overhead varies by model
        let estimatedSpecialTokens = messages.count * 4

        return TokenCount(
            count: totalTokens + estimatedSpecialTokens,
            text: "",
            tokenizer: modelId,
            promptTokens: totalTokens,
            specialTokens: estimatedSpecialTokens
        )
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Encodes text to token IDs.
    ///
    /// - Parameters:
    ///   - text: Text to encode.
    ///   - model: Model whose tokenizer to use.
    /// - Returns: Array of token IDs.
    /// - Throws: `AIError` if encoding fails.
    public func encode(
        _ text: String,
        for model: ModelID
    ) async throws -> [Int] {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Encode text using model loader
        return try await modelLoader.encode(text: text, for: model)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Decodes token IDs back to text.
    ///
    /// - Parameters:
    ///   - tokens: Token IDs to decode.
    ///   - model: Model whose tokenizer to use.
    ///   - skipSpecialTokens: Whether to skip special tokens in output.
    /// - Returns: Decoded text string.
    /// - Throws: `AIError` if decoding fails.
    public func decode(
        _ tokens: [Int],
        for model: ModelID,
        skipSpecialTokens: Bool
    ) async throws -> String {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Decode tokens using model loader
        // Note: skipSpecialTokens is not directly supported by mlx-swift-lm
        // The tokenizer.decode() handles this automatically in most cases
        return try await modelLoader.decode(tokens: tokens, for: model)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }
}

// MARK: - Private Implementation

extension MLXProvider {

    #if arch(arm64)
    /// Performs non-streaming generation using ChatSession.
    ///
    /// Uses the high-level ChatSession API from mlx-swift-lm for
    /// simpler and more reliable generation.
    private func performGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Load model container
        let container = try await modelLoader.loadModel(identifier: model)

        // Track timing
        let startTime = Date()

        // Create generation parameters
        let params = createGenerateParameters(from: config)

        // Create chat session with the container and parameters
        let session = MLXLMCommon.ChatSession(container, generateParameters: params)

        // Build prompt from messages
        let prompt = buildPrompt(from: messages)

        // Generate response
        var generatedText = ""
        var tokenCount = 0

        // Use streaming internally to track token count
        for try await chunk in session.streamResponse(to: prompt) {
            // Check cancellation
            try Task.checkCancellation()
            if isCancelled {
                return GenerationResult(
                    text: generatedText,
                    tokenCount: tokenCount,
                    generationTime: Date().timeIntervalSince(startTime),
                    tokensPerSecond: 0,
                    finishReason: .cancelled
                )
            }

            generatedText += chunk
            tokenCount += 1
        }

        // Calculate metrics
        let duration = Date().timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

        return GenerationResult(
            text: generatedText,
            tokenCount: tokenCount,
            generationTime: duration,
            tokensPerSecond: tokensPerSecond,
            finishReason: .stop
        )
    }

    /// Performs streaming generation using ChatSession.
    ///
    /// Uses the high-level ChatSession API from mlx-swift-lm for
    /// simpler and more reliable streaming.
    private func performStreamingGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async {
        do {
            guard case .mlx = model else {
                continuation.finish(throwing: AIError.invalidInput("MLXProvider only supports .mlx() models"))
                return
            }

            // Reset cancellation flag
            isCancelled = false

            // Load model container
            let container = try await modelLoader.loadModel(identifier: model)

            // Create generation parameters
            let params = createGenerateParameters(from: config)

            // Create chat session with the container and parameters
            let session = MLXLMCommon.ChatSession(container, generateParameters: params)

            // Build prompt from messages
            let prompt = buildPrompt(from: messages)

            // Track timing
            let startTime = Date()
            var totalTokens = 0

            // Stream response
            for try await chunk in session.streamResponse(to: prompt) {
                // Check cancellation using Task.checkCancellation()
                try Task.checkCancellation()
                if isCancelled {
                    let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
                    continuation.yield(finalChunk)
                    continuation.finish()
                    return
                }

                totalTokens += 1

                // Calculate current throughput
                let elapsed = Date().timeIntervalSince(startTime)
                let tokensPerSecond = elapsed > 0 ? Double(totalTokens) / elapsed : 0

                // Yield chunk
                let generationChunk = GenerationChunk(
                    text: chunk,
                    tokenCount: 1,
                    tokensPerSecond: tokensPerSecond,
                    isComplete: false
                )
                continuation.yield(generationChunk)
            }

            // Send completion chunk
            let finalChunk = GenerationChunk.completion(finishReason: .stop)
            continuation.yield(finalChunk)
            continuation.finish()

        } catch is CancellationError {
            let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
            continuation.yield(finalChunk)
            continuation.finish()
        } catch {
            continuation.finish(throwing: AIError.generationFailed(underlying: SendableError(error)))
        }
    }

    /// Builds a simple prompt string from messages.
    ///
    /// ChatSession handles conversation context internally, so we pass the
    /// last user message. For multi-turn conversations, system prompts are
    /// included as context.
    private func buildPrompt(from messages: [Message]) -> String {
        // Find the system message if present
        let systemMessage = messages.first { $0.role == .system }

        // Get the last user message
        let lastUserMessage = messages.last { $0.role == .user }

        // Build the prompt
        var prompt = ""

        if let system = systemMessage {
            prompt += "System: \(system.content.textValue)\n\n"
        }

        // Include recent conversation context (excluding system which is already handled)
        let recentMessages = messages.suffix(6).filter { $0.role != .system }
        for message in recentMessages {
            let rolePrefix: String
            switch message.role {
            case .user: rolePrefix = "User"
            case .assistant: rolePrefix = "Assistant"
            case .system: continue // Filtered out above, but compiler needs this
            case .tool: rolePrefix = "Tool"
            }
            prompt += "\(rolePrefix): \(message.content.textValue)\n"
        }

        // If we only have a single user message, just return its content
        if messages.count == 1, let only = messages.first, only.role == .user {
            return only.content.textValue
        }

        return prompt.isEmpty ? (lastUserMessage?.content.textValue ?? "") : prompt
    }

    /// Converts SwiftAI GenerateConfig to mlx-swift-lm GenerateParameters.
    private func createGenerateParameters(from config: GenerateConfig) -> GenerateParameters {
        var params = GenerateParameters()

        // Token limits
        if let maxTokens = config.maxTokens {
            params.maxTokens = maxTokens
        }

        // Sampling parameters
        params.temperature = config.temperature
        params.topP = config.topP

        // Repetition penalty
        params.repetitionPenalty = config.repetitionPenalty

        return params
    }
    #endif
}

// MARK: - Non-arm64 Stubs

#if !arch(arm64)
extension MLXProvider {
    /// Stub for non-Apple Silicon - all methods throw unavailable error.
    ///
    /// MLX requires Apple Silicon (arm64) architecture.
}
#endif
