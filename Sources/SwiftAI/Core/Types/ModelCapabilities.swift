//
//  ModelCapabilities.swift
//  SwiftAI
//
//  Created on 2025-12-17.
//

import Foundation

// MARK: - ModelCapabilities

/// Describes the capabilities supported by a language model.
///
/// Use this type to determine what operations a model can perform before attempting
/// inference. This helps avoid runtime errors and enables compile-time capability checks.
///
/// ## Usage
///
/// ### Using Presets
/// ```swift
/// let model = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
/// let capabilities = ModelCapabilities.textOnly
///
/// if capabilities.supportsTextGeneration {
///     let response = try await provider.generate("Hello", model: model)
/// }
/// ```
///
/// ### Custom Capabilities
/// ```swift
/// let capabilities = ModelCapabilities(
///     supportsVision: true,
///     supportsTextGeneration: true,
///     supportsEmbeddings: false,
///     architectureType: .llava,
///     contextWindowSize: 8192
/// )
/// ```
///
/// ### Architecture-Based Detection
/// ```swift
/// let architecture = ArchitectureType.qwen2VL
/// let capabilities = ModelCapabilities(
///     supportsVision: architecture.supportsVision,
///     supportsTextGeneration: true,
///     supportsEmbeddings: false,
///     architectureType: architecture,
///     contextWindowSize: 32768
/// )
/// ```
public struct ModelCapabilities: Sendable, Hashable {

    // MARK: - Properties

    /// Whether the model supports vision (image) inputs.
    ///
    /// Vision-capable models can process both text and images in their inputs,
    /// enabling multimodal workflows like image captioning or visual question answering.
    public let supportsVision: Bool

    /// Whether the model supports text generation.
    ///
    /// Most language models support text generation. This is typically `true` for
    /// LLMs and VLMs, but `false` for embedding-only models.
    public let supportsTextGeneration: Bool

    /// Whether the model can generate embeddings.
    ///
    /// Embedding models produce dense vector representations of input text,
    /// useful for semantic search, RAG workflows, and similarity comparisons.
    public let supportsEmbeddings: Bool

    /// The model's architecture type, if known.
    ///
    /// This helps determine model-specific behavior and capabilities.
    /// For example, `llava` architectures support vision, while `bert`
    /// architectures are embedding-only.
    public let architectureType: ArchitectureType?

    /// The maximum context window size in tokens, if known.
    ///
    /// This determines how many tokens (input + output) the model can process
    /// in a single generation call. Common values:
    /// - 2048: Smaller models
    /// - 8192: Standard models
    /// - 32768+: Long-context models
    public let contextWindowSize: Int?

    // MARK: - Initialization

    /// Creates a model capabilities descriptor.
    ///
    /// - Parameters:
    ///   - supportsVision: Whether the model can process image inputs.
    ///   - supportsTextGeneration: Whether the model can generate text.
    ///   - supportsEmbeddings: Whether the model can generate embeddings.
    ///   - architectureType: The model's architecture, if known.
    ///   - contextWindowSize: The maximum context window size in tokens, if known.
    public init(
        supportsVision: Bool,
        supportsTextGeneration: Bool,
        supportsEmbeddings: Bool,
        architectureType: ArchitectureType? = nil,
        contextWindowSize: Int? = nil
    ) {
        self.supportsVision = supportsVision
        self.supportsTextGeneration = supportsTextGeneration
        self.supportsEmbeddings = supportsEmbeddings
        self.architectureType = architectureType
        self.contextWindowSize = contextWindowSize
    }

    // MARK: - Static Presets

    /// Standard text-only language model capabilities.
    ///
    /// Use for models like Llama, Mistral, Qwen, Phi, etc. that process
    /// text inputs and generate text outputs.
    ///
    /// ## Example
    /// ```swift
    /// let model = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
    /// let capabilities = ModelCapabilities.textOnly
    /// ```
    public static let textOnly = ModelCapabilities(
        supportsVision: false,
        supportsTextGeneration: true,
        supportsEmbeddings: false,
        architectureType: nil,
        contextWindowSize: nil
    )

    /// Vision-language model (VLM) capabilities.
    ///
    /// Use for multimodal models like Llava, Qwen2-VL, Pixtral, etc.
    /// that can process both text and images.
    ///
    /// ## Example
    /// ```swift
    /// let model = ModelIdentifier.mlx("mlx-community/llava-1.5-7b-4bit")
    /// let capabilities = ModelCapabilities.vlm
    ///
    /// let messages = Messages {
    ///     Message.user {
    ///         MessageContent.text("What's in this image?")
    ///         MessageContent.image(url: imageURL)
    ///     }
    /// }
    /// ```
    public static let vlm = ModelCapabilities(
        supportsVision: true,
        supportsTextGeneration: true,
        supportsEmbeddings: false,
        architectureType: .vlm,
        contextWindowSize: nil
    )

    /// Embedding model capabilities.
    ///
    /// Use for embedding-only models like BERT, BGE, Nomic that generate
    /// dense vector representations without text generation.
    ///
    /// ## Example
    /// ```swift
    /// let model = ModelIdentifier.huggingFace("BAAI/bge-small-en-v1.5")
    /// let capabilities = ModelCapabilities.embedding
    ///
    /// let embeddings = try await provider.embed(
    ///     ["Hello world", "Goodbye world"],
    ///     model: model
    /// )
    /// ```
    public static let embedding = ModelCapabilities(
        supportsVision: false,
        supportsTextGeneration: false,
        supportsEmbeddings: true,
        architectureType: nil,
        contextWindowSize: nil
    )
}

// MARK: - ArchitectureType

/// Represents the underlying architecture of a language model.
///
/// This enum categorizes models by their architecture family, which determines
/// their capabilities and behavior. Use the `supportsVision` property to check
/// if an architecture supports multimodal inputs.
///
/// ## Usage
///
/// ### Architecture Detection
/// ```swift
/// let architecture = ArchitectureType.llava
/// if architecture.supportsVision {
///     print("This model can process images")
/// }
/// ```
///
/// ### Capability Construction
/// ```swift
/// let capabilities = ModelCapabilities(
///     supportsVision: ArchitectureType.qwen2VL.supportsVision,
///     supportsTextGeneration: true,
///     supportsEmbeddings: false,
///     architectureType: .qwen2VL,
///     contextWindowSize: 32768
/// )
/// ```
public enum ArchitectureType: String, Sendable, Codable, CaseIterable {

    // MARK: - Text-Only Architectures

    /// Llama architecture (Meta).
    ///
    /// Includes Llama 2, Llama 3, Llama 3.1, Llama 3.2 text models.
    /// Text-only, decoder-only transformer architecture.
    case llama

    /// Mistral architecture (Mistral AI).
    ///
    /// Includes Mistral 7B, Mixtral MoE models.
    /// Text-only, optimized for efficiency.
    case mistral

    /// Qwen architecture (Alibaba).
    ///
    /// Includes Qwen 1.5, Qwen 2 text models.
    /// Text-only, multilingual support.
    case qwen

    /// Phi architecture (Microsoft).
    ///
    /// Includes Phi-2, Phi-3 models.
    /// Text-only, small-scale efficient models.
    case phi

    /// Gemma architecture (Google).
    ///
    /// Includes Gemma 2B, Gemma 7B models.
    /// Text-only, open weights.
    case gemma

    // MARK: - Vision-Language Architectures

    /// Generic vision-language model.
    ///
    /// Use when the specific VLM architecture is unknown.
    case vlm

    /// Llava architecture (Liu et al.).
    ///
    /// Vision-language model combining CLIP and Llama.
    /// Supports image understanding with text generation.
    case llava

    /// Qwen2-VL architecture (Alibaba).
    ///
    /// Multimodal version of Qwen supporting vision and text.
    /// High-quality image understanding.
    case qwen2VL = "qwen2_vl"

    /// Pixtral architecture (Mistral AI).
    ///
    /// Multimodal model from Mistral AI.
    /// Combines vision and text capabilities.
    case pixtral

    /// PaliGemma architecture (Google).
    ///
    /// Vision-language variant of Gemma.
    /// Optimized for vision-text tasks.
    case paligemma

    /// Idefics architecture (HuggingFace).
    ///
    /// Open vision-language model.
    /// Supports interleaved image-text inputs.
    case idefics

    /// Llama 3.2 Vision (Meta).
    ///
    /// Multimodal Llama 3.2 models with vision support.
    /// Native vision understanding in Llama architecture.
    case mllama

    /// Phi-3 Vision (Microsoft).
    ///
    /// Multimodal version of Phi-3.
    /// Combines vision and text in a small efficient model.
    case phi3Vision = "phi3_v"

    /// CogVLM (Tsinghua).
    ///
    /// Cognitive Vision-Language Model.
    /// Research-focused multimodal model.
    case cogvlm

    /// InternVL (Shanghai AI Lab).
    ///
    /// Open-source vision-language foundation model.
    /// Strong vision understanding capabilities.
    case internvl

    /// MiniCPM-V (ModelBest).
    ///
    /// Efficient vision-language model.
    /// Optimized for edge deployment.
    case minicpmV = "minicpm_v"

    /// Florence (Microsoft).
    ///
    /// Vision foundation model family.
    /// Supports multiple vision tasks.
    case florence

    /// BLIP (Salesforce).
    ///
    /// Bootstrapping Language-Image Pre-training.
    /// Image captioning and VQA capabilities.
    case blip

    // MARK: - Embedding Architectures

    /// BERT architecture (Google).
    ///
    /// Bidirectional encoder for embeddings.
    /// Classic embedding model, no text generation.
    case bert

    /// BGE architecture (BAAI).
    ///
    /// Beijing Academy of AI embeddings.
    /// High-quality semantic embeddings.
    case bge

    /// Nomic architecture (Nomic AI).
    ///
    /// Nomic Embed models for embeddings.
    /// Optimized for retrieval tasks.
    case nomic

    // MARK: - Computed Properties

    /// Whether this architecture supports vision (image) inputs.
    ///
    /// Returns `true` for all vision-language architectures:
    /// - `vlm`, `llava`, `qwen2VL`, `pixtral`, `paligemma`, `idefics`, `mllama`
    ///
    /// Returns `false` for text-only and embedding-only architectures.
    ///
    /// ## Example
    /// ```swift
    /// let llava = ArchitectureType.llava
    /// print(llava.supportsVision) // true
    ///
    /// let llama = ArchitectureType.llama
    /// print(llama.supportsVision) // false
    /// ```
    public var supportsVision: Bool {
        switch self {
        case .vlm, .llava, .qwen2VL, .pixtral, .paligemma, .idefics, .mllama,
             .phi3Vision, .cogvlm, .internvl, .minicpmV, .florence, .blip:
            return true
        case .llama, .mistral, .qwen, .phi, .gemma, .bert, .bge, .nomic:
            return false
        }
    }
}
