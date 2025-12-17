// FMConfiguration.swift
// SwiftAI

import Foundation

#if canImport(FoundationModels)

/// Configuration options for Apple Foundation Models provider.
///
/// `FMConfiguration` controls system instructions, prewarming behavior,
/// response length limits, and generation parameters for the on-device
/// Apple Foundation Models language model (iOS 26+, macOS 26+).
///
/// ## Usage
/// ```swift
/// // Use defaults
/// let config = FMConfiguration.default
///
/// // Use a preset for conversational apps
/// let config = FMConfiguration.conversational
///
/// // Customize with fluent API
/// let config = FMConfiguration.default
///     .instructions("You are a helpful coding assistant.")
///     .prewarm(true)
///     .maxResponseLength(500)
///     .temperature(0.8)
/// ```
///
/// ## Presets
/// - `default`: Standard configuration for general use
/// - `minimal`: Lightweight configuration without prewarming
/// - `conversational`: Optimized for chat applications with prewarming
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
@available(iOS 26.0, macOS 26.0, *)
public struct FMConfiguration: Sendable, Hashable {

    // MARK: - Session Configuration

    /// System instructions for the language model session.
    ///
    /// Provides context and behavior guidelines that persist across
    /// all prompts in the session. Use this to define the assistant's
    /// role, personality, or constraints.
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.instructions("""
    ///     You are a Swift programming expert. Provide concise,
    ///     idiomatic Swift code examples.
    ///     """)
    /// ```
    ///
    /// - Note: If `nil`, no system instructions are provided.
    public var instructions: String?

    /// Whether to prewarm the model on provider initialization.
    ///
    /// Prewarming loads the model into memory ahead of time,
    /// reducing latency for the first generation request.
    /// Recommended for interactive applications.
    ///
    /// - Note: Increases memory usage while the provider is active.
    /// - Default: `false`
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.prewarm(true)
    /// let provider = FoundationModelsProvider(configuration: config)
    /// ```
    public var prewarmOnInit: Bool

    // MARK: - Generation Parameters

    /// Maximum response length in tokens.
    ///
    /// Limits the length of generated text. If `nil`, no explicit
    /// limit is set (uses system default).
    ///
    /// - Note: Actual token count may be slightly lower due to
    ///   generation stopping conditions.
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.maxResponseLength(500)
    /// ```
    public var maxResponseLength: Int?

    /// Default temperature for generation.
    ///
    /// Controls randomness in text generation:
    /// - Lower values (0.1-0.5): More focused and deterministic
    /// - Medium values (0.6-0.8): Balanced creativity and coherence
    /// - Higher values (0.9-1.0): More creative and diverse
    ///
    /// - Note: Valid range is 0.0 to 1.0. Values outside this range
    ///   are automatically clamped.
    /// - Default: 0.7
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.temperature(0.3)
    /// ```
    public var defaultTemperature: Float

    // MARK: - Initialization

    /// Creates a Foundation Models configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - instructions: System instructions for the session (default: nil).
    ///   - prewarmOnInit: Whether to prewarm the model (default: false).
    ///   - maxResponseLength: Maximum response length in tokens (default: nil).
    ///   - defaultTemperature: Generation temperature (default: 0.7).
    public init(
        instructions: String? = nil,
        prewarmOnInit: Bool = false,
        maxResponseLength: Int? = nil,
        defaultTemperature: Float = 0.7
    ) {
        self.instructions = instructions
        self.prewarmOnInit = prewarmOnInit
        self.maxResponseLength = maxResponseLength.map { max(1, $0) } // Ensure at least 1
        self.defaultTemperature = max(0.0, min(1.0, defaultTemperature)) // Clamp to [0.0, 1.0]
    }

    // MARK: - Static Presets

    /// Default balanced configuration.
    ///
    /// Good for general-purpose text generation without prewarming.
    ///
    /// ## Configuration
    /// - instructions: nil
    /// - prewarmOnInit: false
    /// - maxResponseLength: nil (system default)
    /// - defaultTemperature: 0.7
    public static let `default` = FMConfiguration()

    /// Minimal configuration without prewarming.
    ///
    /// Best for one-off or infrequent generations where
    /// memory efficiency is more important than first-token latency.
    ///
    /// ## Configuration
    /// - instructions: nil
    /// - prewarmOnInit: false
    /// - maxResponseLength: 200
    /// - defaultTemperature: 0.5
    ///
    /// ## Usage
    /// ```swift
    /// let provider = FoundationModelsProvider(configuration: .minimal)
    /// ```
    public static let minimal = FMConfiguration(
        prewarmOnInit: false,
        maxResponseLength: 200,
        defaultTemperature: 0.5
    )

    /// Conversational configuration with prewarming.
    ///
    /// Optimized for chat applications and interactive use cases.
    /// Prewarms the model for fast first-response times.
    ///
    /// ## Configuration
    /// - instructions: "You are a helpful, friendly assistant."
    /// - prewarmOnInit: true
    /// - maxResponseLength: nil (system default)
    /// - defaultTemperature: 0.7
    ///
    /// ## Usage
    /// ```swift
    /// let provider = FoundationModelsProvider(configuration: .conversational)
    /// ```
    public static let conversational = FMConfiguration(
        instructions: "You are a helpful, friendly assistant.",
        prewarmOnInit: true,
        maxResponseLength: nil,
        defaultTemperature: 0.7
    )
}

// MARK: - Fluent API

@available(iOS 26.0, macOS 26.0, *)
extension FMConfiguration {

    /// Returns a copy with the specified system instructions.
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.instructions("You are a coding assistant.")
    /// ```
    ///
    /// - Parameter text: System instructions, or `nil` to remove instructions.
    /// - Returns: A new configuration with the updated instructions.
    public func instructions(_ text: String?) -> FMConfiguration {
        var copy = self
        copy.instructions = text
        return copy
    }

    /// Returns a copy with the specified prewarming setting.
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.prewarm(true)
    /// ```
    ///
    /// - Parameter enabled: Whether to prewarm the model on initialization.
    /// - Returns: A new configuration with the updated prewarming setting.
    public func prewarm(_ enabled: Bool) -> FMConfiguration {
        var copy = self
        copy.prewarmOnInit = enabled
        return copy
    }

    /// Returns a copy with the specified maximum response length.
    ///
    /// Response length is automatically clamped to at least 1 token.
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.maxResponseLength(500)
    /// ```
    ///
    /// - Parameter length: Maximum response length in tokens, or `nil` for system default.
    /// - Returns: A new configuration with the updated response length.
    public func maxResponseLength(_ length: Int?) -> FMConfiguration {
        var copy = self
        copy.maxResponseLength = length.map { max(1, $0) }
        return copy
    }

    /// Returns a copy with the specified default temperature.
    ///
    /// Temperature is automatically clamped to the valid range [0.0, 1.0].
    ///
    /// ## Usage
    /// ```swift
    /// let config = FMConfiguration.default.temperature(0.3)
    /// ```
    ///
    /// - Parameter temp: Generation temperature (0.0 to 1.0).
    /// - Returns: A new configuration with the clamped temperature.
    public func temperature(_ temp: Float) -> FMConfiguration {
        var copy = self
        copy.defaultTemperature = max(0.0, min(1.0, temp))
        return copy
    }
}

#else

// MARK: - Stub for Unsupported Platforms

/// Foundation Models configuration (iOS 26+ only).
///
/// This is a placeholder for platforms that don't support Apple Foundation Models.
/// The real implementation is only available on iOS 26.0+ and macOS 26.0+.
///
/// - Warning: Attempting to use this on unsupported platforms will result in
///   compilation errors or runtime unavailability.
public struct FMConfiguration: Sendable, Hashable {
    private init() {}

    /// Placeholder: Not available on this platform.
    public static let `default` = FMConfiguration()
}

#endif
