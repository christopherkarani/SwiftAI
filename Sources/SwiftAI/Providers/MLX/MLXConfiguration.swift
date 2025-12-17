// MLXConfiguration.swift
// SwiftAI

import Foundation

/// Configuration options for MLX local inference on Apple Silicon.
///
/// `MLXConfiguration` controls memory management, compute preferences,
/// and KV cache settings for optimal performance on different Apple Silicon devices.
///
/// ## Usage
/// ```swift
/// // Use defaults
/// let config = MLXConfiguration.default
///
/// // Use a preset optimized for your device
/// let config = MLXConfiguration.m1Optimized
///
/// // Customize with fluent API
/// let config = MLXConfiguration.default
///     .memoryLimit(.gigabytes(8))
///     .prefillStepSize(256)
///     .withQuantizedKVCache(bits: 4)
/// ```
///
/// ## Presets
/// - `default`: Balanced configuration for general use
/// - `memoryEfficient`: Uses quantized KV cache for memory-constrained devices
/// - `highPerformance`: Large prefill steps for maximum throughput
/// - `m1Optimized`: Tuned for M1 chips (~8GB RAM)
/// - `mProOptimized`: Tuned for M1/M2/M3 Pro/Max (~16-32GB RAM)
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
public struct MLXConfiguration: Sendable, Hashable {

    // MARK: - Memory Management

    /// Maximum memory the model can use.
    ///
    /// If `nil`, uses system default based on available memory.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.memoryLimit(.gigabytes(8))
    /// ```
    public var memoryLimit: ByteCount?

    /// Whether to use memory mapping for model weights.
    ///
    /// Memory mapping reduces initial load time but may increase memory pressure.
    ///
    /// - Note: Default is `true`.
    public var useMemoryMapping: Bool

    /// Maximum entries in the KV cache.
    ///
    /// Limits context length to control memory usage.
    /// If `nil`, no explicit limit is set.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.kvCacheLimit(4096)
    /// ```
    public var kvCacheLimit: Int?

    // MARK: - Compute Preferences

    /// Number of tokens to process in each prefill step.
    ///
    /// Larger values improve throughput but use more memory.
    ///
    /// - Note: Must be at least 1. Invalid values are clamped.
    /// - Default: 512
    public var prefillStepSize: Int

    /// Whether to use quantized (compressed) KV cache.
    ///
    /// Reduces memory usage at slight quality cost.
    ///
    /// - Note: Default is `false`.
    public var useQuantizedKVCache: Bool

    /// Bit depth for KV cache quantization (4 or 8).
    ///
    /// Only used when `useQuantizedKVCache` is `true`.
    ///
    /// - Note: Values outside 4-8 range are automatically clamped.
    /// - Default: 4
    public var kvQuantizationBits: Int

    // MARK: - Initialization

    /// Creates an MLX configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - memoryLimit: Maximum memory the model can use (default: nil).
    ///   - useMemoryMapping: Whether to use memory mapping for weights (default: true).
    ///   - kvCacheLimit: Maximum entries in KV cache (default: nil).
    ///   - prefillStepSize: Tokens per prefill step (default: 512).
    ///   - useQuantizedKVCache: Use compressed KV cache (default: false).
    ///   - kvQuantizationBits: Bit depth for quantization, 4 or 8 (default: 4).
    public init(
        memoryLimit: ByteCount? = nil,
        useMemoryMapping: Bool = true,
        kvCacheLimit: Int? = nil,
        prefillStepSize: Int = 512,
        useQuantizedKVCache: Bool = false,
        kvQuantizationBits: Int = 4
    ) {
        self.memoryLimit = memoryLimit
        self.useMemoryMapping = useMemoryMapping
        self.kvCacheLimit = kvCacheLimit
        self.prefillStepSize = max(1, prefillStepSize)
        self.useQuantizedKVCache = useQuantizedKVCache
        self.kvQuantizationBits = max(4, min(8, kvQuantizationBits)) // Clamp to valid range
    }

    // MARK: - Static Presets

    /// Default balanced configuration.
    ///
    /// Good for general-purpose inference on most Apple Silicon devices.
    ///
    /// ## Configuration
    /// - memoryLimit: nil (system default)
    /// - useMemoryMapping: true
    /// - prefillStepSize: 512
    /// - useQuantizedKVCache: false
    public static let `default` = MLXConfiguration()

    /// Memory-efficient configuration using quantized KV cache.
    ///
    /// Good for devices with limited RAM (8GB or less).
    ///
    /// ## Configuration
    /// - useQuantizedKVCache: true
    /// - kvQuantizationBits: 4
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .memoryEfficient)
    /// ```
    public static let memoryEfficient = MLXConfiguration(
        useQuantizedKVCache: true,
        kvQuantizationBits: 4
    )

    /// High-performance configuration with large prefill steps.
    ///
    /// Best for devices with ample RAM (32GB+).
    ///
    /// ## Configuration
    /// - prefillStepSize: 1024
    /// - useQuantizedKVCache: false
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .highPerformance)
    /// ```
    public static let highPerformance = MLXConfiguration(
        prefillStepSize: 1024,
        useQuantizedKVCache: false
    )

    /// Optimized for M1 chips with ~8GB RAM.
    ///
    /// Uses conservative memory limits and quantized KV cache
    /// to maximize compatibility on base M1 devices.
    ///
    /// ## Configuration
    /// - memoryLimit: 6 GB
    /// - prefillStepSize: 256
    /// - useQuantizedKVCache: true
    /// - kvQuantizationBits: 4
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .m1Optimized)
    /// ```
    public static let m1Optimized = MLXConfiguration(
        memoryLimit: .gigabytes(6),
        prefillStepSize: 256,
        useQuantizedKVCache: true,
        kvQuantizationBits: 4
    )

    /// Optimized for M1/M2/M3 Pro/Max with ~16-32GB RAM.
    ///
    /// Uses larger memory limits and disables quantization
    /// for better quality on Pro/Max devices.
    ///
    /// ## Configuration
    /// - memoryLimit: 12 GB
    /// - prefillStepSize: 512
    /// - useQuantizedKVCache: false
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .mProOptimized)
    /// ```
    public static let mProOptimized = MLXConfiguration(
        memoryLimit: .gigabytes(12),
        prefillStepSize: 512,
        useQuantizedKVCache: false
    )
}

// MARK: - Fluent API

extension MLXConfiguration {

    /// Returns a copy with the specified memory limit.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.memoryLimit(.gigabytes(8))
    /// ```
    ///
    /// - Parameter limit: Maximum memory the model can use, or `nil` for system default.
    /// - Returns: A new configuration with the updated memory limit.
    public func memoryLimit(_ limit: ByteCount?) -> MLXConfiguration {
        var copy = self
        copy.memoryLimit = limit
        return copy
    }

    /// Returns a copy with the specified memory mapping setting.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.useMemoryMapping(false)
    /// ```
    ///
    /// - Parameter enabled: Whether to use memory mapping for model weights.
    /// - Returns: A new configuration with the updated setting.
    public func useMemoryMapping(_ enabled: Bool) -> MLXConfiguration {
        var copy = self
        copy.useMemoryMapping = enabled
        return copy
    }

    /// Returns a copy with the specified KV cache limit.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.kvCacheLimit(4096)
    /// ```
    ///
    /// - Parameter limit: Maximum entries in KV cache, or `nil` for no limit.
    /// - Returns: A new configuration with the updated KV cache limit.
    public func kvCacheLimit(_ limit: Int?) -> MLXConfiguration {
        var copy = self
        copy.kvCacheLimit = limit
        return copy
    }

    /// Returns a copy with the specified prefill step size.
    ///
    /// Prefill step size is automatically clamped to at least 1.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.prefillStepSize(256)
    /// ```
    ///
    /// - Parameter size: Number of tokens to process in each prefill step.
    /// - Returns: A new configuration with the clamped prefill step size.
    public func prefillStepSize(_ size: Int) -> MLXConfiguration {
        var copy = self
        copy.prefillStepSize = max(1, size)
        return copy
    }

    /// Returns a copy configured for quantized KV cache.
    ///
    /// Bit depth is automatically clamped to the valid range [4, 8].
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.withQuantizedKVCache(bits: 4)
    /// ```
    ///
    /// - Parameter bits: Bit depth for quantization (4 or 8, default: 4).
    /// - Returns: A new configuration with quantized KV cache enabled.
    public func withQuantizedKVCache(bits: Int = 4) -> MLXConfiguration {
        var copy = self
        copy.useQuantizedKVCache = true
        copy.kvQuantizationBits = max(4, min(8, bits))
        return copy
    }

    /// Returns a copy with quantized KV cache disabled.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.withoutQuantizedKVCache()
    /// ```
    ///
    /// - Returns: A new configuration with quantized KV cache disabled.
    public func withoutQuantizedKVCache() -> MLXConfiguration {
        var copy = self
        copy.useQuantizedKVCache = false
        return copy
    }
}
