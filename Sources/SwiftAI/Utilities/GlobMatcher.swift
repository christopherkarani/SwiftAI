// GlobMatcher.swift
// SwiftAI
//
// A simple glob pattern matcher for filtering files by pattern.
// Converts glob patterns (* and ?) to regular expressions.
//
// Copyright 2025. MIT License.

import Foundation

/// A glob pattern matcher that converts wildcard patterns to regular expressions.
///
/// `GlobMatcher` supports basic glob patterns:
/// - `*` matches zero or more characters
/// - `?` matches exactly one character
///
/// All regex metacharacters are properly escaped for literal matching.
///
/// ## Usage
/// ```swift
/// let matcher = GlobMatcher("*.safetensors")
/// matcher?.matches("model.safetensors") // true
/// matcher?.matches("config.json") // false
/// ```
///
/// - Note: Returns `nil` if the pattern cannot be converted to a valid regex.
public struct GlobMatcher: Sendable {
    private let regex: NSRegularExpression

    /// Creates a glob matcher from a wildcard pattern.
    ///
    /// The pattern is converted to a regular expression with the following rules:
    /// - `*` becomes `.*` (matches zero or more characters)
    /// - `?` becomes `.` (matches exactly one character)
    /// - Special regex characters are escaped for literal matching
    ///
    /// The resulting regex is anchored with `^` and `$` for exact matching.
    ///
    /// ## Example
    /// ```swift
    /// let matcher = GlobMatcher("model-*.safetensors")
    /// matcher?.matches("model-00001.safetensors") // true
    /// matcher?.matches("model.safetensors") // false (missing part after -)
    /// ```
    ///
    /// - Parameter pattern: A glob pattern string.
    /// - Returns: A matcher instance, or `nil` if the pattern is invalid.
    public init?(_ pattern: String) {
        var escaped = ""
        for ch in pattern {
            switch ch {
            case "*":
                escaped += ".*"
            case "?":
                escaped += "."
            case ".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
                escaped += "\\\(ch)"
            default:
                escaped += String(ch)
            }
        }

        do {
            regex = try NSRegularExpression(pattern: "^\(escaped)$")
        } catch {
            return nil
        }
    }

    /// Tests whether the given text matches the glob pattern.
    ///
    /// - Parameter text: The text to match against the pattern.
    /// - Returns: `true` if the text matches the pattern, `false` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let matcher = GlobMatcher("*.json")!
    /// matcher.matches("config.json") // true
    /// matcher.matches("model.safetensors") // false
    /// ```
    public func matches(_ text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
