//
//  RateLimitInfo.swift
//  SwiftAI
//
//  Rate limiting information from API response headers.
//

import Foundation

/// Rate limiting information extracted from API response headers.
///
/// Anthropic provides detailed rate limit headers that help clients
/// implement intelligent request pacing and avoid hitting limits.
///
/// ## Example
///
/// ```swift
/// let result = try await provider.generate(...)
/// if let rateLimitInfo = result.rateLimitInfo {
///     print("Remaining requests: \(rateLimitInfo.remainingRequests ?? 0)")
///     print("Request ID: \(rateLimitInfo.requestId ?? "unknown")")
/// }
/// ```
///
/// ## Headers Extracted
///
/// - `request-id`: Unique request identifier for debugging
/// - `anthropic-organization-id`: Organization ID
/// - `anthropic-ratelimit-requests-limit`: Max requests per minute
/// - `anthropic-ratelimit-tokens-limit`: Max tokens per minute
/// - `anthropic-ratelimit-requests-remaining`: Remaining requests
/// - `anthropic-ratelimit-tokens-remaining`: Remaining tokens
/// - `anthropic-ratelimit-requests-reset`: Reset time for requests
/// - `anthropic-ratelimit-tokens-reset`: Reset time for tokens
/// - `retry-after`: Wait time for 429 errors
public struct RateLimitInfo: Sendable, Hashable, Codable {

    // MARK: - Request Identification

    /// Unique request identifier for debugging with provider support.
    public let requestId: String?

    /// Organization ID associated with the API key.
    public let organizationId: String?

    // MARK: - Rate Limits

    /// Maximum requests allowed per minute.
    public let limitRequests: Int?

    /// Maximum tokens allowed per minute.
    public let limitTokens: Int?

    // MARK: - Remaining Capacity

    /// Remaining requests in current minute.
    public let remainingRequests: Int?

    /// Remaining tokens in current minute.
    public let remainingTokens: Int?

    // MARK: - Reset Times

    /// Timestamp when request limit resets.
    public let resetRequests: Date?

    /// Timestamp when token limit resets.
    public let resetTokens: Date?

    // MARK: - Retry Information

    /// Seconds to wait before retrying (429 errors only).
    public let retryAfter: TimeInterval?

    // MARK: - Initialization

    /// Initialize from HTTP response headers.
    ///
    /// - Parameter headers: Dictionary of HTTP response headers (handles case-insensitive matching)
    public init(headers: [String: String]) {
        // Normalize to lowercase for case-insensitive matching
        let normalizedHeaders = headers.reduce(into: [String: String]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }

        self.requestId = normalizedHeaders["request-id"]
        self.organizationId = normalizedHeaders["anthropic-organization-id"]

        self.limitRequests = normalizedHeaders["anthropic-ratelimit-requests-limit"].flatMap(Int.init)
        self.limitTokens = normalizedHeaders["anthropic-ratelimit-tokens-limit"].flatMap(Int.init)

        self.remainingRequests = normalizedHeaders["anthropic-ratelimit-requests-remaining"].flatMap(Int.init)
        self.remainingTokens = normalizedHeaders["anthropic-ratelimit-tokens-remaining"].flatMap(Int.init)

        // Parse RFC 3339 timestamps with fractional seconds support
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatterWithoutFractional = ISO8601DateFormatter()
        formatterWithoutFractional.formatOptions = [.withInternetDateTime]

        // Helper to parse date with fallback
        func parseDate(_ value: String?) -> Date? {
            guard let value = value else { return nil }
            return formatterWithFractional.date(from: value) ?? formatterWithoutFractional.date(from: value)
        }

        self.resetRequests = parseDate(normalizedHeaders["anthropic-ratelimit-requests-reset"])
        self.resetTokens = parseDate(normalizedHeaders["anthropic-ratelimit-tokens-reset"])

        self.retryAfter = normalizedHeaders["retry-after"].flatMap(TimeInterval.init)
    }

    /// Initialize with explicit values.
    public init(
        requestId: String? = nil,
        organizationId: String? = nil,
        limitRequests: Int? = nil,
        limitTokens: Int? = nil,
        remainingRequests: Int? = nil,
        remainingTokens: Int? = nil,
        resetRequests: Date? = nil,
        resetTokens: Date? = nil,
        retryAfter: TimeInterval? = nil
    ) {
        self.requestId = requestId
        self.organizationId = organizationId
        self.limitRequests = limitRequests
        self.limitTokens = limitTokens
        self.remainingRequests = remainingRequests
        self.remainingTokens = remainingTokens
        self.resetRequests = resetRequests
        self.resetTokens = resetTokens
        self.retryAfter = retryAfter
    }
}
