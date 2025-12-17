# SwiftAI Implementation Plan

> **Version**: 2.0.0
> **Phases**: 13 (reduced from 15)
> **Status**: Phases 1-11 Complete, Phase 12 Complete, Phase 13 In Progress

---

## Overview

SwiftAI is a focused Swift SDK for LLM inference across **two providers**:
- **MLX**: Local inference on Apple Silicon (offline, privacy-preserving)
- **HuggingFace**: Cloud inference via HF Inference API (online, model variety)

### What SwiftAI Is NOT

SwiftAI intentionally does **not** wrap Apple Foundation Models. Rationale:
- Apple's Foundation Models API is already clean and Swift-native
- Wrapping it adds overhead without meaningful value
- SwiftAgents (the orchestration layer) will provide its own adapter if needed

### Design Principles

1. **Explicit Model Selection** — No auto-detection; developers choose their provider
2. **Swift 6.2 Concurrency** — Actors, Sendable types, AsyncSequence throughout
3. **Protocol-Oriented** — Provider abstraction via protocols with associated types
4. **Progressive Disclosure** — Simple API for beginners, full control for experts
5. **Focused Scope** — Do two things well rather than three things poorly

### Phase Dependencies

```
Phase 1 (Setup) ─┬─► Phase 2 (Protocols) ─┬─► Phase 4 (Messages)
                 │                        │
                 │                        └─► Phase 5 (Config)
                 │
                 └─► Phase 3 (Models) ────────► Phase 6 (Streaming)
                                                     │
                                                     ▼
Phase 7 (Errors) ◄──────────────────────────────────┘
     │
     ▼
Phase 8 (Tokens) ──► Phase 9 (Model Mgmt)
     │
     ▼
Phase 10 (MLX) ──► Phase 11 (HF) ──► Phase 12 (Builders) ──► Phase 13 (Polish)
```

---

## Phase 1: Project Setup & Package.swift ✅ COMPLETE

**Dependencies**: None

### Objective
Establish the Swift package structure, configure dependencies, and create the foundational directory layout.

### Deliverables
- `Package.swift` with all dependencies
- Directory structure matching specification
- `.gitignore` and `.swiftlint.yml`
- Basic README.md

### Implementation

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftAI", targets: ["SwiftAI"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
```

### Acceptance Criteria
- [x] `swift build` compiles without errors
- [x] `swift package resolve` succeeds
- [x] Directory structure matches specification
- [x] README has basic project description

---

## Phase 2: Core Protocols ✅ COMPLETE

**Dependencies**: Phase 1

### Objective
Define the foundational protocols that all providers and capabilities must conform to.

### Deliverables
- `Sources/SwiftAI/Core/Protocols/AIProvider.swift`
- `Sources/SwiftAI/Core/Protocols/TextGenerator.swift`
- `Sources/SwiftAI/Core/Protocols/EmbeddingGenerator.swift`
- `Sources/SwiftAI/Core/Protocols/Transcriber.swift`
- `Sources/SwiftAI/Core/Protocols/TokenCounter.swift`
- `Sources/SwiftAI/Core/Protocols/ModelManaging.swift`

### Key Protocols

```swift
public protocol AIProvider<Response>: Actor, Sendable {
    associatedtype Response: Sendable
    associatedtype StreamChunk: Sendable
    associatedtype ModelID: ModelIdentifying

    var isAvailable: Bool { get async }
    var availabilityStatus: ProviderAvailability { get async }

    func generate(messages: [Message], model: ModelID, config: GenerateConfig) async throws -> Response
    func stream(messages: [Message], model: ModelID, config: GenerateConfig) -> AsyncThrowingStream<StreamChunk, Error>
    func cancelGeneration() async
}
```

### Acceptance Criteria
- [x] All protocols defined with full documentation
- [x] Primary associated types used where beneficial
- [x] All protocols require Sendable conformance
- [x] Protocol extensions provide default implementations

---

## Phase 3: Model Identification ✅ COMPLETE

**Dependencies**: Phase 1

### Objective
Create the type-safe model identification system and model registry.

### Deliverables
- `Sources/SwiftAI/Core/Types/ModelIdentifier.swift`
- `Sources/SwiftAI/ModelManagement/ModelRegistry.swift`

### Key Types

```swift
public protocol ModelIdentifying: Hashable, Sendable, CustomStringConvertible {
    var rawValue: String { get }
    var displayName: String { get }
    var provider: ProviderType { get }
}

public enum ModelIdentifier: ModelIdentifying, Codable {
    case mlx(String)
    case huggingFace(String)
}

// Registry with convenience constants
extension ModelIdentifier {
    static let llama3_2_1B = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
    static let llama3_2_3B = ModelIdentifier.mlx("mlx-community/Llama-3.2-3B-Instruct-4bit")
    // ... more models
}
```

### Acceptance Criteria
- [x] ModelIdentifier enum with MLX and HuggingFace cases
- [x] ModelIdentifying protocol defined
- [x] ProviderType enum defined
- [x] Model registry with common model constants

---

## Phase 4: Message Types ✅ COMPLETE

**Dependencies**: Phase 2

### Objective
Implement the message types for representing conversations.

### Deliverables
- `Sources/SwiftAI/Core/Types/Message.swift`
- Unit tests for Message types

### Key Types

```swift
public struct Message: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let role: Role
    public let content: Content
    public let timestamp: Date
    public let metadata: MessageMetadata?

    public enum Role: String, Sendable, Codable { case system, user, assistant, tool }
    public enum Content: Sendable, Hashable, Codable { case text(String), parts([ContentPart]) }
}
```

### Acceptance Criteria
- [x] Message struct with all properties
- [x] Convenience initializers (.system, .user, .assistant)
- [x] Codable conformance working
- [x] Unit tests passing

---

## Phase 5: Generation Configuration ✅ COMPLETE

**Dependencies**: Phase 2

### Objective
Implement GenerateConfig with all sampling parameters and fluent API.

### Deliverables
- `Sources/SwiftAI/Core/Types/GenerateConfig.swift`
- Unit tests for config validation

### Key Features

```swift
public struct GenerateConfig: Sendable, Hashable, Codable {
    public var maxTokens: Int?
    public var temperature: Float
    public var topP: Float
    public var topK: Int?
    // ... more params

    // Presets
    public static let `default` = GenerateConfig()
    public static let creative = GenerateConfig(temperature: 0.9)
    public static let precise = GenerateConfig(temperature: 0.1)

    // Fluent API
    public func temperature(_ value: Float) -> GenerateConfig
    public func maxTokens(_ value: Int?) -> GenerateConfig
}
```

### Acceptance Criteria
- [x] All sampling parameters defined
- [x] Fluent API methods work correctly
- [x] Value clamping for temperature/topP
- [x] Presets defined

---

## Phase 6: Streaming Infrastructure ✅ COMPLETE

**Dependencies**: Phase 2, 5

### Objective
Build the streaming infrastructure for token-by-token generation.

### Deliverables
- `Sources/SwiftAI/Core/Streaming/GenerationStream.swift`
- `Sources/SwiftAI/Core/Streaming/GenerationChunk.swift`
- `Sources/SwiftAI/Core/Types/GenerationResult.swift`

### Key Types

```swift
public struct GenerationStream: AsyncSequence, Sendable {
    public var text: AsyncThrowingMapSequence<GenerationStream, String>
    public func collect() async throws -> String
    public func collectWithMetadata() async throws -> GenerationResult
}

public struct GenerationChunk: Sendable, Hashable {
    public let text: String
    public let tokenCount: Int
    public let tokensPerSecond: Double?
    public let isComplete: Bool
    public let finishReason: FinishReason?
}
```

### Acceptance Criteria
- [x] GenerationStream conforms to AsyncSequence
- [x] Chunk collection works correctly
- [x] Cancellation handling via onTermination
- [x] Tests for streaming behavior

---

## Phase 7: Error Handling ✅ COMPLETE

**Dependencies**: Phase 6

### Objective
Implement comprehensive error handling with AIError enum.

### Deliverables
- `Sources/SwiftAI/Core/Errors/AIError.swift`
- `Sources/SwiftAI/Core/Errors/SendableError.swift`
- `Sources/SwiftAI/Core/Types/ProviderAvailability.swift`

### Key Types

```swift
public enum AIError: Error, Sendable, LocalizedError {
    case providerUnavailable(reason: UnavailabilityReason)
    case modelNotFound(ModelIdentifier)
    case generationFailed(underlying: Error)
    case tokenLimitExceeded(count: Int, limit: Int)
    case cancelled
    // ... more cases

    public var errorDescription: String? { /* localized descriptions */ }
}
```

### Acceptance Criteria
- [x] All error cases defined
- [x] LocalizedError conformance
- [x] UnavailabilityReason enum complete
- [x] ProviderAvailability struct defined

---

## Phase 8: Token Counting API ✅ COMPLETE

**Dependencies**: Phase 7

### Objective
Implement token counting protocol and types.

### Deliverables
- `Sources/SwiftAI/Core/Types/TokenCount.swift`
- Token counting protocol extensions

### Key Features

```swift
public struct TokenCount: Sendable, Hashable {
    public let count: Int
    public let text: String
    public let tokenizer: String
    public let tokenIds: [Int]?

    public func fitsInContext(of size: Int) -> Bool
    public func remainingIn(context size: Int) -> Int
}

extension TokenCounter {
    public func truncateToFit(messages: [Message], model: ModelID, contextSize: Int) async throws -> [Message]
}
```

### Acceptance Criteria
- [x] TokenCount struct complete
- [x] Context window helpers work
- [x] Truncation extension implemented
- [x] Integration with SwiftAgents patterns

---

## Phase 9: Model Management ✅ COMPLETE

**Dependencies**: Phase 8

### Objective
Implement the model download, cache, and lifecycle management system.

### Deliverables
- `Sources/SwiftAI/ModelManagement/ModelManager.swift`
- `Sources/SwiftAI/ModelManagement/ModelCache.swift`
- `Sources/SwiftAI/ModelManagement/DownloadProgress.swift`

### Key Features

```swift
public actor ModelManager {
    public static let shared = ModelManager()

    public func cachedModels() -> [CachedModelInfo]
    public func isCached(_ model: ModelIdentifier) -> Bool
    public func download(_ model: ModelIdentifier, progress: @escaping (DownloadProgress) -> Void) async throws -> URL
    public func delete(_ model: ModelIdentifier) throws
    public func cacheSize() -> ByteCount
}
```

### Acceptance Criteria
- [x] ModelManager actor complete
- [x] Download with progress works
- [x] Cache management functional
- [x] Observable DownloadTask

---

## Phase 10: MLX Provider ✅ COMPLETE

**Dependencies**: Phase 9

### Objective
Implement the MLX local inference provider.

### Deliverables
- `Sources/SwiftAI/Providers/MLX/MLXProvider.swift`
- `Sources/SwiftAI/Providers/MLX/MLXModelLoader.swift`
- `Sources/SwiftAI/Providers/MLX/MLXConfiguration.swift`

### Key Implementation

```swift
public actor MLXProvider: AIProvider, TextGenerator, TokenCounter {
    // Full implementation with:
    // - Model loading
    // - Generation (sync and streaming)
    // - Token counting
}
```

### Acceptance Criteria
- [x] Availability check works on Apple Silicon
- [x] Generation produces output
- [x] Streaming works correctly
- [x] Token counting accurate
- [x] Memory management handled

---

## Phase 11: HuggingFace Provider ✅ COMPLETE

**Dependencies**: Phase 10

### Objective
Implement the HuggingFace Inference API provider.

### Deliverables
- `Sources/SwiftAI/Providers/HuggingFace/HuggingFaceProvider.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFInferenceClient.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFTokenProvider.swift`
- `Sources/SwiftAI/Providers/HuggingFace/HFConfiguration.swift`

### Key Implementation

```swift
public actor HuggingFaceProvider: AIProvider, TextGenerator, EmbeddingGenerator, Transcriber {
    // HTTP client for HF Inference API
    // SSE streaming support
    // Token management
}
```

### Acceptance Criteria
- [x] Authentication works
- [x] Chat completions functional
- [x] SSE streaming implemented
- [x] Transcription works
- [x] Rate limiting handled

---

## Phase 12: Result Builders ✅ COMPLETE

**Dependencies**: Phase 11

### Objective
Implement result builders for declarative API construction.

### Deliverables
- `Sources/SwiftAI/Builders/MessageBuilder.swift`
- `Sources/SwiftAI/Builders/PromptBuilder.swift`
- Convenience extensions

### Key Implementation

```swift
@resultBuilder
public struct MessageBuilder {
    // Build expressions for Message
    // Support for optionals, arrays, conditionals
}

public func Messages(@MessageBuilder _ builder: () -> [Message]) -> [Message]
```

### Acceptance Criteria
- [x] MessageBuilder works with conditionals
- [x] PromptBuilder components functional
- [x] For-in loop support
- [x] Documentation complete

---

## Phase 13: Testing & Polish 🔄 IN PROGRESS

**Dependencies**: Phase 12

### Objective
Complete test coverage, documentation, and final polish.

### Deliverables
- Comprehensive test suite
- Full API documentation
- Example code
- Performance benchmarks

### Tasks
1. Achieve 80%+ test coverage
2. All public APIs documented
3. Example project in Examples/
4. Performance benchmarks for MLX
5. README with quick start guide

### Current Test Files (15 files, ~7,534 lines)
- Core types: Message, GenerateConfig, ModelIdentifier, TokenCount, TranscriptionResult
- Protocols: ProtocolCompilationTests
- Errors: ErrorTests
- Streaming: StreamingTests
- Providers: HuggingFaceProviderTests
- Builders: MessageBuilderTests, PromptBuilderTests
- Model Management: ModelManagementTests
- ChatSession: ChatSessionTests

### Missing Tests
- [ ] MLXProvider integration tests (requires Apple Silicon)
- [ ] Extension tests (ArrayExtensions, StringExtensions, etc.)

### Acceptance Criteria
- [ ] Test coverage >80%
- [ ] All public APIs documented
- [ ] Examples compile and run
- [ ] README complete
- [ ] SwiftLint clean

---

## Removed Phases

### ~~Phase 12: Foundation Models Provider~~ REMOVED

**Reason**: Apple's Foundation Models API is already clean and Swift-native. Wrapping it adds overhead without meaningful value. SwiftAgents will provide its own adapter if unified orchestration is needed.

### ~~Phase 14: Macros~~ REMOVED

**Reason**:
- Apple's `@Generable` already handles structured output for Foundation Models
- MLX uses grammar constraints (different mechanism)
- HuggingFace uses API parameters
- Structured output can be achieved via `Codable` + runtime schema generation without macro complexity

---

## Success Metrics

1. **API Ergonomics**: Simple use cases < 5 lines of code
2. **Performance**: MLX inference 30+ tokens/second on M1
3. **Reliability**: 99%+ success rate for valid operations
4. **Documentation**: 100% public API documentation coverage
5. **Test Coverage**: >80% code coverage

---

## SwiftAgents Integration Notes

SwiftAgents (the orchestration layer) will:
1. Define its own `LLMProvider` protocol for agent orchestration
2. Provide `SwiftAIAdapter` to wrap MLX/HuggingFace providers
3. Provide `FoundationModelsAdapter` to wrap Apple FM directly
4. Own the unified abstraction it needs for orchestration

Key SwiftAI APIs that SwiftAgents depends on:
- `TokenCounter` protocol for context window management
- `EmbeddingGenerator` for RAG workflows
- `ModelManager` for downloads and caching
- `GenerationStream` for streaming responses

---

## Cleanup Tasks

The following stubs can be removed as they are no longer needed:

1. `Sources/SwiftAI/Providers/FoundationModels/FoundationModelsProvider.swift` - DELETE
2. `Sources/SwiftAI/Providers/FoundationModels/FMSessionManager.swift` - DELETE
3. `Sources/SwiftAI/Providers/FoundationModels/FMConfiguration.swift` - DELETE (or keep for documentation)
4. `Sources/SwiftAIMacros/` directory - DELETE entirely
5. `Sources/SwiftAI/Core/Streaming/StreamBuffer.swift` - DELETE (functionality in GenerationStream)

---

*End of SwiftAI Implementation Plan v2.0*
