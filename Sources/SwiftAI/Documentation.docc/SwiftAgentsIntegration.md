# SwiftAgents Integration

Integrate SwiftAI providers with the SwiftAgents framework for building AI agent applications.

## Overview

SwiftAI can be used as the inference backend for [SwiftAgents](https://github.com/christopherkarani/SwiftAgents) through an adapter pattern. This guide shows how to create an adapter that bridges SwiftAI providers to SwiftAgents' `InferenceProvider` protocol.

## Creating the Adapter Package

Create a new Swift package that depends on both SwiftAI and SwiftAgents:

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "SwiftAIAgents",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SwiftAIAgents", targets: ["SwiftAIAgents"])
    ],
    dependencies: [
        .package(url: "https://github.com/your-org/SwiftAI.git", from: "1.0.0"),
        .package(url: "https://github.com/christopherkarani/SwiftAgents.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftAIAgents",
            dependencies: ["SwiftAI", "SwiftAgents"]
        )
    ]
)
```

## Inference Provider Adapter

Create an adapter that wraps any SwiftAI `TextGenerator`:

```swift
import SwiftAI
import SwiftAgents

/// Adapts a SwiftAI TextGenerator to SwiftAgents' InferenceProvider.
public struct SwiftAIInferenceProvider<Provider: TextGenerator>: InferenceProvider {

    private let provider: Provider
    private let modelID: Provider.ModelID
    private let config: GenerateConfig

    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default
    ) {
        self.provider = provider
        self.modelID = model
        self.config = config
    }

    // MARK: - InferenceProvider

    public func generate(prompt: String) async throws -> String {
        try await provider.generate(prompt, model: modelID, config: config)
    }

    public func generate(messages: [SwiftAgents.Message]) async throws -> String {
        // Convert SwiftAgents messages to SwiftAI messages
        let swiftAIMessages = messages.map { message in
            SwiftAI.Message(
                role: convertRole(message.role),
                content: .text(message.content)
            )
        }
        let result = try await provider.generate(
            messages: swiftAIMessages,
            model: modelID,
            config: config
        )
        return result.text
    }

    private func convertRole(_ role: SwiftAgents.MessageRole) -> SwiftAI.Message.Role {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        case .system: return .system
        }
    }
}
```

## Tool Integration

SwiftAI's `AITool` protocol can be adapted to SwiftAgents' `Tool` protocol:

```swift
import SwiftAI
import SwiftAgents

/// Wraps a SwiftAI AITool for use with SwiftAgents.
public struct SwiftAIToolWrapper<T: AITool>: SwiftAgents.Tool {

    private let aiTool: T

    public init(_ tool: T) {
        self.aiTool = tool
    }

    public var name: String { aiTool.name }
    public var description: String { aiTool.description }

    public var parameters: SwiftAgents.ToolParameters {
        // Convert SwiftAI Schema to SwiftAgents parameters
        convertSchema(T.parameters)
    }

    public func execute(arguments: [String: Any]) async throws -> String {
        // Convert arguments to JSON data and call the AITool
        let data = try JSONSerialization.data(withJSONObject: arguments)
        let result = try await aiTool.call(data)
        return result.text
    }

    private func convertSchema(_ schema: SwiftAI.Schema) -> SwiftAgents.ToolParameters {
        // Implementation depends on SwiftAgents' parameter format
        // This is a simplified example
        SwiftAgents.ToolParameters(
            jsonSchema: schema.toJSONSchema()
        )
    }
}
```

## Structured Output with Generable

Use SwiftAI's `@Generable` types with SwiftAgents:

```swift
import SwiftAI
import SwiftAgents

// Define a Generable type
@Generable
struct TaskAnalysis {
    @Guide("Summary of the task")
    let summary: String

    @Guide("Estimated complexity", .anyOf(["low", "medium", "high"]))
    let complexity: String

    @Guide("Suggested approach")
    let approach: String
}

// Use with SwiftAgents
extension SwiftAIInferenceProvider {

    /// Generates a structured response using a Generable type.
    public func generate<T: Generable>(
        prompt: String,
        returning type: T.Type
    ) async throws -> T {
        // Add schema to prompt
        let schemaJSON = T.schema.toJSONSchema()
        let structuredPrompt = """
        \(prompt)

        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        let response = try await generate(prompt: structuredPrompt)
        let content = try StructuredContent(json: response)
        return try T(from: content)
    }
}
```

## Usage Example

```swift
import SwiftAI
import SwiftAgents
import SwiftAIAgents

// Create SwiftAI provider
let anthropic = AnthropicProvider(apiKey: "your-key")

// Wrap as SwiftAgents InferenceProvider
let inferenceProvider = SwiftAIInferenceProvider(
    provider: anthropic,
    model: .claude4Sonnet,
    config: .default.temperature(0.7)
)

// Create SwiftAgents agent with SwiftAI backend
let agent = Agent(
    name: "Assistant",
    instructions: "You are a helpful assistant.",
    inferenceProvider: inferenceProvider,
    tools: [
        SwiftAIToolWrapper(WeatherTool()),
        SwiftAIToolWrapper(SearchTool())
    ]
)

// Run the agent
let response = try await agent.run("What's the weather in Paris?")
print(response)
```

## Topics

### Adapters
- ``SwiftAIInferenceProvider``
- ``SwiftAIToolWrapper``

### Configuration
- ``GenerateConfig``
- ``ToolDefinition``
