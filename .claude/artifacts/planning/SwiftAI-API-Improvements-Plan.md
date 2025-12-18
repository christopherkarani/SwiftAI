# SwiftAI API Improvements Plan

> **Goal**: Transform SwiftAI into an Apple-quality API with progressive disclosure, leveraging generics, macros, result builders, and DSL patterns inspired by SwiftUI and Foundation Models.
>
> **Status**: Approved for Implementation
> **Created**: December 2025

---

## Executive Summary

After comprehensive analysis of the SwiftAI codebase and Apple's modern API patterns (Foundation Models, SwiftUI), this plan recommends **12 key improvements** organized into 4 tiers based on impact and complexity.

### Current State Strengths
- Excellent Swift 6.2 concurrency (actors, Sendable, async/await)
- Good protocol architecture with primary associated types
- Existing result builders (MessageBuilder, PromptBuilder)
- Fluent configuration API with presets

### Key Improvement Areas
1. **Macros** - Add `@StructuredOutput` for type-safe generation
2. **Result Builders** - Expand DSL coverage (providers, configs, pipelines)
3. **Generics** - Improve type inference and reduce boilerplate
4. **Progressive Disclosure** - 4-level API from simple to expert

### Implementation Decisions
1. **Macro Priority**: Prioritize `@StructuredOutput` macro implementation first
2. **API Compatibility**: Supplement existing config-based API (keep both approaches)
3. **Scope**: Implement all 4 tiers for comprehensive API improvement

---

## API Before & After

### Before (Current)
```swift
let config = GenerateConfig.default.temperature(0.8)
let messages = [Message.system("You are helpful."), Message.user("Hello")]
let result = try await provider.generate(messages: messages, model: .llama3_2_1B, config: config)
```

### After (With Improvements)
```swift
// Level 1: One-liner for beginners
let response = try await SwiftAI.generate("Hello", model: .llama3_2_1B)

// Level 4: Expert with type-safe structured output
@StructuredOutput struct ContactInfo {
    @Field(description: "Full name") var name: String
    @Field(description: "Email", .pattern("^[\\w.-]+@[\\w.-]+$")) var email: String
}

let contact: ContactInfo = try await provider
    .generate("Extract: John Doe, john@example.com", model: .llama3_2_1B, as: ContactInfo.self)
    .temperature(0.3)
```

---

## Tier 1: High-Impact API Improvements

### 1.1 `@StructuredOutput` Macro (Inspired by Foundation Models @Generable)

**Current Problem**: No compile-time support for structured JSON output.

**Proposed Solution**:
```swift
// User defines their output type with the macro
@StructuredOutput(description: "Extract contact information")
struct ContactInfo {
    @Field(description: "Full name of the person")
    var name: String

    @Field(description: "Email address", .pattern("^[\\w.-]+@[\\w.-]+$"))
    var email: String

    @Field(description: "Age in years", .range(0...150))
    var age: Int?
}

// Usage - type-safe generation
let contact: ContactInfo = try await provider.generate(
    "Extract: John Doe, john@example.com, 30 years old",
    model: .llama3_2_1B,
    as: ContactInfo.self
)
```

**Implementation**:
- Create `@StructuredOutput` macro using swift-syntax
- Auto-generate JSON schema from struct
- Add `@Field` for property-level constraints
- Integrate with `TextGenerator` protocol

**Files to Create**:
- `Sources/SwiftAIMacros/StructuredOutputMacro.swift`
- `Sources/SwiftAIMacros/FieldMacro.swift`
- `Sources/SwiftAI/Core/Types/FieldConstraint.swift`

---

### 1.2 Provider Result Builder DSL

**Current Problem**: Provider initialization is imperative.

**Proposed Solution**:
```swift
// Declarative provider configuration
let provider = MLXProvider {
    Configuration {
        memoryLimit(.gigabytes(8))
        cachePolicy(.lru(maxModels: 2))
        quantization(.q4)
    }

    Defaults {
        temperature(0.7)
        maxTokens(512)
    }

    ErrorHandling {
        onModelNotFound { .fallback(to: .phi3Mini) }
        onOutOfMemory { .unloadOldest }
        maxRetries(3)
    }
}
```

**Files to Create**:
- `Sources/SwiftAI/Builders/ProviderBuilder.swift`
- `Sources/SwiftAI/Builders/ProviderComponents.swift`

---

### 1.3 Generation Pipeline Builder

**Current Problem**: Post-processing requires manual chaining.

**Proposed Solution**:
```swift
// Declarative processing pipeline
let result = try await provider.generate(messages, model: .llama3_2_1B) {
    Pipeline {
        Trim()
        ValidateJSON()
        Transform { $0.lowercased() }
        Cache(duration: .minutes(5))
    }
}

// Or as reusable pipeline
let jsonPipeline = Pipeline {
    Trim()
    ExtractJSON()
    Validate(schema: mySchema)
}

let result = try await provider.generate(messages, model: .llama3_2_1B)
    .processed(by: jsonPipeline)
```

**Files to Create**:
- `Sources/SwiftAI/Builders/PipelineBuilder.swift`
- `Sources/SwiftAI/Core/Pipeline/PipelineStep.swift`
- `Sources/SwiftAI/Core/Pipeline/BuiltInSteps.swift`

---

## Tier 2: Progressive Disclosure API

### 2.1 Four-Level API Design

**Level 1 - One-liner (Beginners)**:
```swift
// Absolute minimum - uses sensible defaults
let response = try await SwiftAI.generate("Hello", model: .llama3_2_1B)
```

**Level 2 - Explicit Provider (Standard)**:
```swift
// Explicit provider, still simple
let provider = MLXProvider()
let response = try await provider.generate("Hello", model: .llama3_2_1B)
```

**Level 3 - Configuration (Intermediate)**:
```swift
// Full control over generation parameters
let messages = Messages {
    Message.system("You are helpful.")
    Message.user("Hello")
}

let response = try await provider.generate(
    messages: messages,
    model: .llama3_2_1B,
    config: .default.temperature(0.8).maxTokens(500)
)
```

**Level 4 - Expert (Full Control)**:
```swift
// Everything customizable
let provider = MLXProvider {
    Configuration { memoryLimit(.gigabytes(8)) }
    ErrorHandling { maxRetries(3) }
}

let stream = provider.stream(
    messages: messages,
    model: .mlx("custom/model"),
    config: config
) {
    Pipeline { Validate(schema: mySchema) }
}

for try await chunk in stream {
    // Process with full metadata access
}
```

**Files to Modify**:
- `Sources/SwiftAI/SwiftAI.swift` - Add static convenience methods

---

### 2.2 Modifier Pattern (SwiftUI-style)

**Current Problem**: Configuration is separate from generation call.

**Proposed Solution**:
```swift
// Chainable modifiers like SwiftUI
let response = try await provider
    .generate("Hello", model: .llama3_2_1B)
    .temperature(0.8)
    .maxTokens(500)
    .stopSequences(["END"])
    .timeout(30)
    .retryPolicy(.exponential(maxAttempts: 3))

// Streaming with modifiers
let stream = provider
    .stream(messages, model: .llama3_2_1B)
    .bufferSize(10)
    .onProgress { print("Tokens: \($0)") }
```

**Files to Create**:
- `Sources/SwiftAI/Core/Types/GenerationRequest.swift`
- `Sources/SwiftAI/Core/Extensions/GenerationRequest+Modifiers.swift`

---

## Tier 3: Enhanced Generics & Type Safety

### 3.1 Generic Streaming with Type Inference

**Current Problem**: Two separate streaming methods (`stream()` vs `streamWithMetadata()`).

**Proposed Solution**:
```swift
// Single generic stream method with type inference
let textStream: AsyncThrowingStream<String, Error> = provider.stream(...)
let chunkStream: AsyncThrowingStream<GenerationChunk, Error> = provider.stream(...)

// Or explicit
let stream = provider.stream(..., as: GenerationChunk.self)
```

**Files to Modify**:
- `Sources/SwiftAI/Core/Protocols/TextGenerator.swift`

---

### 3.2 Type-Safe Model Registry

**Current Problem**: Model identifiers are stringly-typed for custom models.

**Proposed Solution**:
```swift
// Extend model registry at compile time
extension ModelIdentifier {
    static let myCustomModel = ModelIdentifier.mlx("org/my-custom-model")
}

// Or use builder for runtime registration
let registry = ModelRegistry {
    Model(.mlx("org/model-1B"), alias: "fast", tags: [.small, .chat])
    Model(.mlx("org/model-7B"), alias: "quality", tags: [.large, .instruct])
    Model(.huggingFace("org/cloud"), alias: "cloud", tags: [.api])
}

let model = registry.resolve(alias: "fast")
let chatModels = registry.filter(by: .chat)
```

**Files to Create**:
- `Sources/SwiftAI/Core/Types/ModelRegistry.swift`
- `Sources/SwiftAI/Builders/ModelRegistryBuilder.swift`

---

### 3.3 Protocol Witness with Capabilities

**Current Problem**: No way to query provider capabilities at runtime.

**Proposed Solution**:
```swift
// Capability protocol for discovery
protocol CapabilityProviding {
    associatedtype Capabilities: OptionSet
    var capabilities: Capabilities { get async }
}

// Usage
if await provider.capabilities.contains(.streaming) {
    // Use streaming API
}
```

**Files to Create**:
- `Sources/SwiftAI/Core/Protocols/CapabilityProviding.swift`
- `Sources/SwiftAI/Core/Types/ProviderCapabilities.swift`

---

## Tier 4: DSL Enhancements

### 4.1 Enhanced Message Builder

**Proposed Enhancements**:
```swift
let messages = Messages {
    // Current - still works
    Message.system("You are helpful.")
    Message.user("Hello")

    // NEW: Implicit role inference
    System("You are helpful.")
    User("Hello")
    Assistant("Hi there!")

    // NEW: Multimodal shorthand
    User {
        Text("What's in this image?")
        Image(data: imageData)
        Image(url: imageURL)
    }

    // NEW: Template variables
    User("Hello, {{name}}!", variables: ["name": userName])
}
```

**Files to Modify**:
- `Sources/SwiftAI/Builders/MessageBuilder.swift`
- Add `Sources/SwiftAI/Builders/MessageShorthands.swift`

---

### 4.2 Configuration Presets Builder

**Proposed Solution**:
```swift
// Define custom presets
extension GenerateConfig {
    static let myPreset = GenerateConfig {
        temperature(0.65)
        maxTokens(1000)
        topP(0.9)
        stopSequences(["###"])
    }
}

// Or runtime preset registration
GenerateConfig.registerPreset("myPreset") {
    temperature(0.65)
    maxTokens(1000)
}
```

**Files to Modify**:
- `Sources/SwiftAI/Core/Types/GenerateConfig.swift`
- Add `Sources/SwiftAI/Builders/ConfigBuilder.swift`

---

### 4.3 Error Recovery DSL

**Proposed Solution**:
```swift
let result = try await provider.generate(messages, model: .llama3_2_1B) {
    Recovery {
        on(.modelNotFound) { .retry(with: .phi3Mini) }
        on(.rateLimited) { .backoff(seconds: $0.retryAfter ?? 5) }
        on(.timeout) { .retry(maxAttempts: 3) }
        on(.outOfMemory) { .unloadAndRetry }
        otherwise { .fail }
    }
}
```

**Files to Create**:
- `Sources/SwiftAI/Builders/RecoveryBuilder.swift`
- `Sources/SwiftAI/Core/Types/RecoveryAction.swift`

---

## Implementation Priority

| Improvement | Impact | Complexity | Priority |
|------------|--------|------------|----------|
| 1.1 @StructuredOutput Macro | High | High | P0 |
| 2.1 Four-Level API | High | Low | P0 |
| 2.2 Modifier Pattern | High | Medium | P1 |
| 1.2 Provider Builder DSL | Medium | Medium | P1 |
| 4.1 Enhanced Message Builder | Medium | Low | P1 |
| 1.3 Pipeline Builder | Medium | Medium | P2 |
| 3.1 Generic Streaming | Medium | Medium | P2 |
| 3.2 Model Registry | Low | Low | P2 |
| 4.2 Config Presets Builder | Low | Low | P3 |
| 4.3 Error Recovery DSL | Low | Medium | P3 |
| 3.3 Capability Protocol | Low | Medium | P3 |

---

## Files Summary

### New Files to Create
```
Sources/SwiftAI/
├── Builders/
│   ├── ProviderBuilder.swift
│   ├── ProviderComponents.swift
│   ├── PipelineBuilder.swift
│   ├── ConfigBuilder.swift
│   ├── RecoveryBuilder.swift
│   ├── ModelRegistryBuilder.swift
│   └── MessageShorthands.swift
├── Core/
│   ├── Types/
│   │   ├── GenerationRequest.swift
│   │   ├── RecoveryAction.swift
│   │   ├── FieldConstraint.swift
│   │   ├── ModelRegistry.swift
│   │   └── ProviderCapabilities.swift
│   ├── Pipeline/
│   │   ├── PipelineStep.swift
│   │   └── BuiltInSteps.swift
│   └── Protocols/
│       └── CapabilityProviding.swift
└── Extensions/
    └── GenerationRequest+Modifiers.swift

Sources/SwiftAIMacros/
├── StructuredOutputMacro.swift
├── FieldMacro.swift
└── Plugin.swift
```

### Files to Modify
```
Sources/SwiftAI/
├── SwiftAI.swift                    # Add static convenience methods
├── Core/
│   ├── Protocols/
│   │   └── TextGenerator.swift      # Generic streaming
│   └── Types/
│       └── GenerateConfig.swift     # Preset builder support
└── Builders/
    └── MessageBuilder.swift         # Enhanced DSL
```

---

## Implementation Phases

### Phase 1: Macro Infrastructure (P0)
1. Create `SwiftAIMacros` target with swift-syntax dependency
2. Implement `@StructuredOutput` macro
3. Implement `@Field` macro with constraints
4. Add `FieldConstraint` types
5. Integrate with `TextGenerator` protocol

### Phase 2: Progressive Disclosure API (P0)
1. Add static convenience methods to `SwiftAI.swift`
2. Implement 4-level API hierarchy
3. Document each level with examples

### Phase 3: Modifier Pattern (P1)
1. Create `GenerationRequest` intermediate type
2. Implement chainable modifier methods
3. Add async execution on await

### Phase 4: Provider Builder DSL (P1)
1. Create `@ProviderBuilder` result builder
2. Implement `Configuration`, `Defaults`, `ErrorHandling` components
3. Update provider initializers

### Phase 5: Enhanced Message Builder (P1)
1. Add shorthand functions (`System()`, `User()`, `Assistant()`)
2. Implement multimodal content builder
3. Add template variable support

### Phase 6: Pipeline Builder (P2)
1. Create `PipelineStep` protocol
2. Implement built-in steps (Trim, ValidateJSON, Transform, etc.)
3. Create `@PipelineBuilder` result builder

### Phase 7: Generic Streaming (P2)
1. Unify `stream()` and `streamWithMetadata()` methods
2. Add type inference for output type
3. Deprecate separate metadata streaming

### Phase 8: Model Registry (P2)
1. Create `ModelRegistry` type
2. Implement `@ModelRegistryBuilder`
3. Add tagging and filtering support

### Phase 9: Config Presets Builder (P3)
1. Add `@ConfigBuilder` result builder
2. Implement runtime preset registration
3. Update `GenerateConfig`

### Phase 10: Error Recovery DSL (P3)
1. Create `RecoveryAction` types
2. Implement `@RecoveryBuilder`
3. Integrate with generation methods

### Phase 11: Capability Protocol (P3)
1. Create `CapabilityProviding` protocol
2. Define `ProviderCapabilities` option set
3. Implement for all providers

---

## Success Criteria

- [ ] All public APIs have doc comments with examples
- [ ] Each API level works independently
- [ ] Existing code continues to work (backward compatible)
- [ ] `swift build` passes without warnings
- [ ] `swift test` passes for all new functionality
- [ ] Progressive disclosure demonstrated in README
