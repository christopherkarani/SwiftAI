// PromptBuilder.swift
// SwiftAI

import Foundation

// MARK: - PromptComponent Protocol

/// A component that can be part of a structured prompt.
///
/// Prompt components provide a higher-level abstraction for building prompts
/// by composing semantic units like system instructions, context, examples,
/// and user queries.
///
/// ## Conformance
/// Types conforming to `PromptComponent` must be `Sendable` for thread safety
/// and implement `render()` to produce their string representation.
///
/// ## Built-in Components
/// - ``SystemInstruction``: System message content
/// - ``UserQuery``: User question or input
/// - ``Context``: Background information with optional label
/// - ``Examples``: Few-shot learning examples
///
/// ## Usage
/// ```swift
/// struct CustomComponent: PromptComponent {
///     let value: String
///     func render() -> String { "Custom: \(value)" }
/// }
/// ```
public protocol PromptComponent: Sendable {
    /// Renders this component as a string.
    ///
    /// - Returns: The string representation of this component.
    func render() -> String
}

// MARK: - SystemInstruction

/// A system instruction component for prompts.
///
/// System instructions set the behavior and context for the AI assistant.
/// They are typically rendered as the first message in a conversation.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a helpful coding assistant.")
///     UserQuery("How do I implement async/await?")
/// }
/// ```
public struct SystemInstruction: PromptComponent {

    /// The system instruction content.
    public let content: String

    /// Creates a system instruction component.
    ///
    /// - Parameter content: The system instruction text.
    public init(_ content: String) {
        self.content = content
    }

    /// Renders the system instruction as a string.
    ///
    /// - Returns: The system instruction content.
    public func render() -> String {
        content
    }
}

// MARK: - UserQuery

/// A user query component for prompts.
///
/// User queries represent the input or question from the human user.
/// They are typically rendered as user messages in the conversation.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are helpful.")
///     UserQuery("What is the meaning of life?")
/// }
/// ```
public struct UserQuery: PromptComponent {

    /// The user query content.
    public let content: String

    /// Creates a user query component.
    ///
    /// - Parameter content: The user's question or input.
    public init(_ content: String) {
        self.content = content
    }

    /// Renders the user query as a string.
    ///
    /// - Returns: The user query content.
    public func render() -> String {
        content
    }
}

// MARK: - Context

/// A context component for prompts.
///
/// Context provides background information, documents, or other relevant
/// data that helps the AI understand the situation better.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a coding assistant.")
///     Context("The user is working on a Swift project.", label: "Background")
///     Context("""
///         func hello() { print("Hello") }
///         """, label: "Code")
///     UserQuery("Can you improve this function?")
/// }
/// ```
public struct Context: PromptComponent {

    /// Optional label for the context section.
    public let label: String?

    /// The context content.
    public let content: String

    /// Creates a context component.
    ///
    /// - Parameters:
    ///   - content: The context information.
    ///   - label: Optional label to prefix the context (e.g., "Background", "Code").
    public init(_ content: String, label: String? = nil) {
        self.content = content
        self.label = label
    }

    /// Renders the context as a string.
    ///
    /// If a label is provided, the format is:
    /// ```
    /// [Label]
    /// content
    /// ```
    ///
    /// - Returns: The formatted context string.
    public func render() -> String {
        if let label = label {
            return "[\(label)]\n\(content)"
        }
        return content
    }
}

// MARK: - Examples

/// A few-shot examples component for prompts.
///
/// Examples provide input-output pairs that demonstrate the expected
/// behavior to the AI model. This technique is known as few-shot learning.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a math tutor.")
///     Examples([
///         (input: "What is 2+2?", output: "4"),
///         (input: "What is 3*4?", output: "12")
///     ])
///     UserQuery("What is 5+7?")
/// }
/// ```
public struct Examples: PromptComponent {

    /// The input-output example pairs.
    public let examples: [(input: String, output: String)]

    /// Creates an examples component.
    ///
    /// - Parameter examples: An array of input-output pairs.
    public init(_ examples: [(input: String, output: String)]) {
        self.examples = examples
    }

    /// Renders the examples as a formatted string.
    ///
    /// Each example is formatted as:
    /// ```
    /// Input: <input>
    /// Output: <output>
    /// ```
    /// Examples are separated by blank lines.
    ///
    /// - Returns: The formatted examples string.
    public func render() -> String {
        examples.map { example in
            "Input: \(example.input)\nOutput: \(example.output)"
        }.joined(separator: "\n\n")
    }
}

// MARK: - EmptyComponent

/// An empty prompt component that renders to an empty string.
///
/// Used internally by the result builder to handle optional components.
public struct EmptyComponent: PromptComponent {

    /// Creates an empty component.
    public init() {}

    /// Renders to an empty string.
    ///
    /// - Returns: An empty string.
    public func render() -> String {
        ""
    }
}

// MARK: - CompositeComponent

/// A composite prompt component that combines multiple components.
///
/// Used internally by the result builder to handle arrays of components.
public struct CompositeComponent: PromptComponent {

    /// The child components.
    public let components: [any PromptComponent]

    /// Creates a composite component.
    ///
    /// - Parameter components: The components to combine.
    public init(components: [any PromptComponent]) {
        self.components = components
    }

    /// Renders all child components, joined by double newlines.
    ///
    /// - Returns: The combined render output.
    public func render() -> String {
        components
            .map { $0.render() }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

// MARK: - PromptContent

/// The content of a structured prompt, containing multiple components.
///
/// `PromptContent` is the primary output of the ``PromptBuilder`` result builder.
/// It provides methods to render the prompt as a string or convert it to
/// an array of ``Message`` objects for use with AI providers.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are helpful.")
///     UserQuery("Hello!")
/// }
///
/// // Render as string
/// let text = prompt.render()
///
/// // Convert to messages
/// let messages = prompt.toMessages()
/// ```
public struct PromptContent: PromptComponent, Sendable {

    /// The components that make up this prompt.
    public let components: [any PromptComponent]

    /// Creates prompt content from an array of components.
    ///
    /// - Parameter components: The prompt components.
    public init(components: [any PromptComponent]) {
        self.components = components
    }

    /// Renders all components as a combined string.
    ///
    /// Components are rendered in order and joined by double newlines.
    /// Empty component renders are filtered out.
    ///
    /// - Returns: The complete prompt as a string.
    public func render() -> String {
        components
            .map { $0.render() }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Converts the prompt content to an array of messages.
    ///
    /// This method intelligently maps components to appropriate message roles:
    /// - ``SystemInstruction`` becomes a system message
    /// - ``UserQuery`` becomes a user message
    /// - ``Examples`` become alternating user/assistant messages
    /// - ``Context`` and other components become user messages
    ///
    /// ## Usage
    /// ```swift
    /// let prompt = Prompt {
    ///     SystemInstruction("You are helpful.")
    ///     Context("Some background info")
    ///     Examples([
    ///         (input: "Hi", output: "Hello!")
    ///     ])
    ///     UserQuery("How are you?")
    /// }
    ///
    /// let messages = prompt.toMessages()
    /// // Results in:
    /// // [.system("You are helpful."),
    /// //  .user("[Context]\nSome background info"),
    /// //  .user("Hi"),
    /// //  .assistant("Hello!"),
    /// //  .user("How are you?")]
    /// ```
    ///
    /// - Returns: An array of messages suitable for AI providers.
    public func toMessages() -> [Message] {
        var messages: [Message] = []

        for component in components {
            switch component {
            case let instruction as SystemInstruction:
                messages.append(.system(instruction.content))

            case let query as UserQuery:
                messages.append(.user(query.content))

            case let examples as Examples:
                for example in examples.examples {
                    messages.append(.user(example.input))
                    messages.append(.assistant(example.output))
                }

            case let context as Context:
                let rendered = context.render()
                if !rendered.isEmpty {
                    messages.append(.user(rendered))
                }

            case let composite as CompositeComponent:
                // Recursively convert composite components
                let subContent = PromptContent(components: composite.components)
                messages.append(contentsOf: subContent.toMessages())

            case let content as PromptContent:
                // Recursively convert nested prompt content
                messages.append(contentsOf: content.toMessages())

            default:
                // For any other component, render as user message
                let rendered = component.render()
                if !rendered.isEmpty {
                    messages.append(.user(rendered))
                }
            }
        }

        return messages
    }
}

// MARK: - PromptBuilder

/// A result builder for declaratively constructing structured prompts.
///
/// `PromptBuilder` enables a SwiftUI-like DSL for building prompts from
/// semantic components. It supports conditionals, loops, and optional content.
///
/// ## Basic Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a helpful assistant.")
///     UserQuery("What is Swift?")
/// }
/// ```
///
/// ## Conditionals
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are helpful.")
///
///     if hasContext {
///         Context(contextString, label: "Background")
///     }
///
///     UserQuery(question)
/// }
/// ```
///
/// ## Loops
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a translator.")
///
///     for document in documents {
///         Context(document.content, label: document.title)
///     }
///
///     UserQuery("Translate the above to Spanish.")
/// }
/// ```
@resultBuilder
public struct PromptBuilder {

    /// Builds a block of prompt components.
    ///
    /// - Parameter components: Variadic list of components.
    /// - Returns: A `PromptContent` containing all components.
    public static func buildBlock(_ components: any PromptComponent...) -> PromptContent {
        PromptContent(components: components)
    }

    /// Builds an optional component.
    ///
    /// - Parameter component: An optional component.
    /// - Returns: The component if present, or an `EmptyComponent`.
    public static func buildOptional(_ component: (any PromptComponent)?) -> any PromptComponent {
        component ?? EmptyComponent()
    }

    /// Builds the first branch of a conditional.
    ///
    /// - Parameter component: The component from the `if` branch.
    /// - Returns: The component unchanged.
    public static func buildEither(first component: any PromptComponent) -> any PromptComponent {
        component
    }

    /// Builds the second branch of a conditional.
    ///
    /// - Parameter component: The component from the `else` branch.
    /// - Returns: The component unchanged.
    public static func buildEither(second component: any PromptComponent) -> any PromptComponent {
        component
    }

    /// Builds an array of components from a loop.
    ///
    /// - Parameter components: Array of components from a `for` loop.
    /// - Returns: A `CompositeComponent` containing all components.
    public static func buildArray(_ components: [any PromptComponent]) -> any PromptComponent {
        CompositeComponent(components: components)
    }

    /// Passes through a single expression.
    ///
    /// - Parameter expression: A prompt component expression.
    /// - Returns: The component unchanged.
    public static func buildExpression(_ expression: any PromptComponent) -> any PromptComponent {
        expression
    }

    /// Handles availability-limited components.
    ///
    /// - Parameter component: A component with availability restrictions.
    /// - Returns: The component unchanged.
    public static func buildLimitedAvailability(_ component: any PromptComponent) -> any PromptComponent {
        component
    }
}

// MARK: - Prompt Function

/// Creates a structured prompt using the result builder DSL.
///
/// This is the primary entry point for building prompts declaratively.
/// Use the various prompt components inside the builder closure.
///
/// ## Usage
/// ```swift
/// let prompt = Prompt {
///     SystemInstruction("You are a coding assistant.")
///
///     Context("The user is working on a Swift project.", label: "Background")
///
///     if hasExamples {
///         Examples([
///             (input: "What is 2+2?", output: "4"),
///             (input: "What is Swift?", output: "A programming language.")
///         ])
///     }
///
///     UserQuery("How do I implement async/await?")
/// }
///
/// // Use the prompt
/// let rendered = prompt.render()
/// let messages = prompt.toMessages()
/// ```
///
/// - Parameter builder: A closure that builds prompt components.
/// - Returns: The constructed `PromptContent`.
public func Prompt(@PromptBuilder _ builder: () -> PromptContent) -> PromptContent {
    builder()
}

// MARK: - PromptContent + ExpressibleByStringLiteral

extension PromptContent: ExpressibleByStringLiteral {

    /// Creates prompt content from a string literal.
    ///
    /// This allows using a simple string where `PromptContent` is expected.
    ///
    /// - Parameter value: The string literal.
    public init(stringLiteral value: String) {
        self.components = [UserQuery(value)]
    }
}

// MARK: - PromptContent + CustomStringConvertible

extension PromptContent: CustomStringConvertible {

    /// A textual representation of the prompt content.
    public var description: String {
        render()
    }
}

// MARK: - PromptContent + CustomDebugStringConvertible

extension PromptContent: CustomDebugStringConvertible {

    /// A debug textual representation of the prompt content.
    public var debugDescription: String {
        "PromptContent(components: \(components.count))\n\(render())"
    }
}
