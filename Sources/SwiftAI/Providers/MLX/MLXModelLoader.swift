// MLXModelLoader.swift
// SwiftAI

import Foundation
#if arch(arm64)
@preconcurrency import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM
// Note: Tokenizer protocol is re-exported through MLXLMCommon
#endif

/// Internal actor for loading and managing MLX model instances.
///
/// Manages model lifecycle including loading, caching in memory, and LRU eviction.
/// Only one model is kept loaded at a time by default to conserve memory.
///
/// ## Overview
///
/// `MLXModelLoader` is an internal actor that handles the low-level details of loading
/// and managing MLX model instances. It integrates with `ModelManager` for downloading
/// and caching model files, and provides LRU eviction when memory is constrained.
///
/// ## Architecture
///
/// ```
/// MLXProvider → MLXModelLoader → ModelManager
///                    ↓
///           LLMModelFactory (mlx-swift-lm)
/// ```
///
/// ## LRU Eviction
///
/// By default, only one model is kept loaded in memory at a time. When a different model
/// is requested, the previous model is automatically unloaded. This can be configured
/// via the `maxLoadedModels` parameter.
///
/// ## Thread Safety
///
/// As an actor, `MLXModelLoader` provides automatic thread safety for all operations.
/// All model loading and access tracking is serialized through the actor's executor.
///
/// - Note: This is an internal implementation detail of the MLX provider and should
///   not be used directly by application code.
internal actor MLXModelLoader {

    // MARK: - Types

    /// Information about a loaded model in memory.
    struct LoadedModel: Sendable {
        /// The model identifier (repository ID).
        let modelId: String

        /// When this model was first loaded into memory.
        let loadedAt: Date

        /// When this model was last accessed (for LRU eviction).
        var lastAccessedAt: Date
    }

    // MARK: - Properties

    /// The MLX configuration for this loader.
    let configuration: MLXConfiguration

    /// Maximum number of models to keep loaded in memory (LRU).
    ///
    /// When this limit is reached, the least recently used model is evicted
    /// before loading a new one.
    let maxLoadedModels: Int

    /// Metadata about loaded models (indexed by model ID).
    private var loadedModels: [String: LoadedModel] = [:]

    #if arch(arm64)
    /// The actual model containers (indexed by model ID).
    ///
    /// Separate from LoadedModel because ModelContainer is a class
    /// and may not be Sendable.
    private var modelContainers: [String: ModelContainer] = [:]
    #endif

    // MARK: - Initialization

    /// Creates a model loader with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The MLX configuration for model loading. Defaults to `.default`.
    ///   - maxLoadedModels: Maximum models to keep in memory. Defaults to 1.
    init(configuration: MLXConfiguration = .default, maxLoadedModels: Int = 1) {
        self.configuration = configuration
        self.maxLoadedModels = max(1, maxLoadedModels)
    }

    // MARK: - Model Loading

    #if arch(arm64)
    /// Loads a model and returns its container.
    ///
    /// If the model is already loaded in memory, returns the cached container
    /// immediately. Otherwise, downloads the model (if needed) and loads it
    /// into memory.
    ///
    /// - Parameter identifier: The model identifier to load.
    /// - Returns: The loaded model container.
    /// - Throws: `AIError` if loading fails.
    ///
    /// ## Error Cases
    /// - `AIError.invalidInput` if identifier is not an MLX model
    /// - `AIError.modelNotCached` if download fails
    /// - `AIError.generationFailed` if model loading fails
    func loadModel(identifier: ModelIdentifier) async throws -> ModelContainer {
        // Validate it's an MLX model
        guard case .mlx(let modelId) = identifier else {
            throw AIError.invalidInput("MLXModelLoader only supports .mlx() model identifiers")
        }

        // Return cached if already loaded
        if let container = modelContainers[modelId] {
            // Update access time
            if var info = loadedModels[modelId] {
                info.lastAccessedAt = Date()
                loadedModels[modelId] = info
            }
            return container
        }

        // Evict if at capacity
        await evictIfNeeded()

        // Create MLX configuration using model ID
        // mlx-swift-lm handles downloading and caching internally via HuggingFace Hub
        let modelConfig = ModelConfiguration(id: modelId)

        // Load the model
        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfig,
                progressHandler: { progress in
                    // Progress tracking for model weight loading
                    // Could expose this via a callback in the future
                }
            )

            // Cache the loaded model
            let info = LoadedModel(
                modelId: modelId,
                loadedAt: Date(),
                lastAccessedAt: Date()
            )
            loadedModels[modelId] = info
            modelContainers[modelId] = container

            // Mark as accessed in ModelManager for LRU tracking
            await ModelManager.shared.markAccessed(identifier)

            return container

        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }
    #endif

    /// Unloads a specific model from memory.
    ///
    /// Removes the model from the in-memory cache. The model files remain
    /// on disk and can be reloaded later.
    ///
    /// - Parameter identifier: The model to unload.
    func unloadModel(identifier: ModelIdentifier) async {
        guard case .mlx(let modelId) = identifier else { return }

        loadedModels.removeValue(forKey: modelId)
        #if arch(arm64)
        modelContainers.removeValue(forKey: modelId)
        #endif
    }

    /// Unloads all models from memory.
    ///
    /// Clears the in-memory cache of all loaded models. Model files remain
    /// on disk and can be reloaded later.
    func unloadAllModels() async {
        loadedModels.removeAll()
        #if arch(arm64)
        modelContainers.removeAll()
        #endif
    }

    /// Checks if a model is currently loaded in memory.
    ///
    /// - Parameter identifier: The model to check.
    /// - Returns: `true` if the model is loaded, `false` otherwise.
    func isLoaded(_ identifier: ModelIdentifier) -> Bool {
        guard case .mlx(let modelId) = identifier else { return false }
        return loadedModels[modelId] != nil
    }

    // MARK: - Tokenizer Access

    #if arch(arm64)
    /// Encodes text to tokens using the model's tokenizer.
    ///
    /// - Parameters:
    ///   - text: The text to encode.
    ///   - identifier: The model whose tokenizer to use.
    /// - Returns: Array of token IDs.
    /// - Throws: `AIError` if encoding fails.
    func encode(text: String, for identifier: ModelIdentifier) async throws -> [Int] {
        let container = try await loadModel(identifier: identifier)
        return await container.perform { context in
            context.tokenizer.encode(text: text)
        }
    }

    /// Decodes tokens to text using the model's tokenizer.
    ///
    /// - Parameters:
    ///   - tokens: The token IDs to decode.
    ///   - identifier: The model whose tokenizer to use.
    /// - Returns: Decoded text string.
    /// - Throws: `AIError` if decoding fails.
    func decode(tokens: [Int], for identifier: ModelIdentifier) async throws -> String {
        let container = try await loadModel(identifier: identifier)
        return await container.perform { context in
            context.tokenizer.decode(tokens: tokens)
        }
    }
    #endif

    // MARK: - Private Helpers

    /// Evicts the least recently used model if at capacity.
    ///
    /// When the number of loaded models reaches `maxLoadedModels`, this method
    /// removes the model with the oldest `lastAccessedAt` timestamp.
    private func evictIfNeeded() async {
        guard loadedModels.count >= maxLoadedModels else { return }

        // Find the least recently accessed model
        let oldest = loadedModels.min { $0.value.lastAccessedAt < $1.value.lastAccessedAt }

        if let oldest = oldest {
            loadedModels.removeValue(forKey: oldest.key)
            #if arch(arm64)
            modelContainers.removeValue(forKey: oldest.key)
            #endif
        }
    }

    /// Resolves the local file path for a model, downloading if necessary.
    ///
    /// - Parameter identifier: The model to resolve.
    /// - Returns: The local file URL for the model.
    /// - Throws: `AIError.modelNotCached` if download fails.
    private func resolveModelPath(for identifier: ModelIdentifier) async throws -> URL {
        // Check if already cached
        if await ModelManager.shared.isCached(identifier) {
            if let path = await ModelManager.shared.localPath(for: identifier) {
                return path
            }
        }

        // Not cached - download it
        do {
            return try await ModelManager.shared.download(identifier, progress: nil)
        } catch {
            throw AIError.modelNotCached(identifier)
        }
    }
}

// MARK: - Non-arm64 Stubs

#if !arch(arm64)
extension MLXModelLoader {
    /// Stub for non-Apple Silicon - always throws.
    ///
    /// MLX requires Apple Silicon (arm64) architecture. On other platforms,
    /// this method throws `AIError.providerUnavailable`.
    ///
    /// - Parameter identifier: The model identifier (ignored).
    /// - Throws: `AIError.providerUnavailable` with reason `.deviceNotSupported`.
    func loadModel(identifier: ModelIdentifier) async throws -> Never {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    /// Stub for non-Apple Silicon - always throws.
    ///
    /// MLX requires Apple Silicon (arm64) architecture. On other platforms,
    /// this method throws `AIError.providerUnavailable`.
    ///
    /// - Parameter identifier: The model identifier (ignored).
    /// - Throws: `AIError.providerUnavailable` with reason `.deviceNotSupported`.
    func tokenizer(for identifier: ModelIdentifier) async throws -> Never {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }
}
#endif
