// URLExtensions.swift
// SwiftAI

import Foundation

// MARK: - URL + Transcription

/// Convenience extensions for transcribing audio files directly from URLs.
///
/// These extensions provide ergonomic methods for transcribing audio without
/// explicitly calling provider methods. They are particularly useful for quick
/// transcription tasks and simple use cases.
///
/// ## Basic Usage
/// ```swift
/// let audioURL = URL(fileURLWithPath: "/path/to/audio.mp3")
/// let provider = HuggingFaceProvider(token: "...")
///
/// // Full transcription
/// let result = try await audioURL.transcribe(
///     with: provider,
///     model: .whisperLargeV3
/// )
/// print(result.text)
/// print("Duration: \(result.duration)s")
/// ```
///
/// ## Text-Only Transcription
/// ```swift
/// // Get just the text, no metadata
/// let text = try await audioURL.transcribeText(
///     with: provider,
///     model: .whisperLargeV3,
///     language: "en"
/// )
/// print(text)
/// ```
///
/// ## Streaming Transcription
/// ```swift
/// // Stream segments as they become available
/// for try await segment in audioURL.streamTranscription(
///     with: provider,
///     model: .whisperLargeV3
/// ) {
///     print("[\(segment.startTime)s]: \(segment.text)")
/// }
/// ```
///
/// ## Subtitle Generation
/// ```swift
/// // Generate SRT subtitles
/// let srt = try await audioURL.transcribeToSRT(
///     with: provider,
///     model: .whisperLargeV3,
///     language: "en"
/// )
/// try srt.write(to: subtitleURL, atomically: true, encoding: .utf8)
///
/// // Generate WebVTT subtitles
/// let vtt = try await audioURL.transcribeToVTT(
///     with: provider,
///     model: .whisperLargeV3
/// )
/// ```
///
/// - Note: All methods are `async throws` and may take significant time for
///   large audio files. Consider using `Task` for cancellation support in
///   UI contexts.
///
/// - SeeAlso: `Transcriber` protocol for provider-level API
/// - SeeAlso: `TranscriptionConfig` for advanced configuration options
/// - SeeAlso: `TranscriptionResult` for detailed output structure
extension URL {

    // MARK: - Full Transcription

    /// Transcribes audio from this URL using the specified provider.
    ///
    /// Performs a complete transcription of the audio file, returning detailed
    /// results including segments, timing information, and metadata.
    ///
    /// ## Usage
    /// ```swift
    /// let audioURL = URL(fileURLWithPath: "/path/to/podcast.mp3")
    /// let provider = MLXProvider()
    ///
    /// let result = try await audioURL.transcribe(
    ///     with: provider,
    ///     model: .whisper,
    ///     config: .detailed
    /// )
    ///
    /// print("Text: \(result.text)")
    /// print("Duration: \(result.duration)s")
    /// print("Processing time: \(result.processingTime)s")
    /// print("Segments: \(result.segments.count)")
    /// ```
    ///
    /// ## Custom Configuration
    /// ```swift
    /// let config = TranscriptionConfig(
    ///     language: "en",
    ///     wordTimestamps: true,
    ///     format: .detailed
    /// )
    ///
    /// let result = try await audioURL.transcribe(
    ///     with: provider,
    ///     model: model,
    ///     config: config
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The transcription provider to use (must conform to `Transcriber`).
    ///   - model: The model identifier for the provider's transcription model.
    ///   - config: Configuration options controlling transcription behavior.
    ///            Defaults to `.default` (auto language detection, text format).
    ///
    /// - Returns: A `TranscriptionResult` containing the full transcription,
    ///            segment breakdown, timing information, and metadata.
    ///
    /// - Throws: `AIError` if:
    ///   - The audio file cannot be read or is in an unsupported format
    ///   - The model cannot be loaded
    ///   - Transcription processing fails
    ///   - The provider encounters an error
    public func transcribe<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        config: TranscriptionConfig = .default
    ) async throws -> TranscriptionResult {
        try await provider.transcribe(
            audioURL: self,
            model: model,
            config: config
        )
    }

    // MARK: - Text-Only Transcription

    /// Transcribes audio from this URL and returns only the text.
    ///
    /// A convenience method for simple transcription tasks where only the
    /// transcribed text is needed, without timing information or metadata.
    ///
    /// This method is equivalent to calling `transcribe(...)` and accessing
    /// the `text` property, but provides a more ergonomic API for common cases.
    ///
    /// ## Usage
    /// ```swift
    /// let audioURL = URL(fileURLWithPath: "/path/to/voice-note.m4a")
    ///
    /// // Simple text extraction
    /// let text = try await audioURL.transcribeText(
    ///     with: provider,
    ///     model: .whisperLargeV3
    /// )
    /// print(text)
    ///
    /// // With language hint
    /// let text = try await audioURL.transcribeText(
    ///     with: provider,
    ///     model: .whisperLargeV3,
    ///     language: "es"  // Spanish
    /// )
    /// ```
    ///
    /// ## When to Use
    /// Use this method when:
    /// - You only need the transcribed text
    /// - Timing information is not required
    /// - You want simpler, more readable code
    ///
    /// For detailed transcription with segments and timing, use `transcribe(...)` instead.
    ///
    /// - Parameters:
    ///   - provider: The transcription provider to use.
    ///   - model: The model identifier for the provider's transcription model.
    ///   - language: Optional language code (ISO 639-1) to hint the transcription.
    ///              If `nil`, language will be auto-detected. Default is `nil`.
    ///
    /// - Returns: The transcribed text as a `String`.
    ///
    /// - Throws: `AIError` if transcription fails.
    ///
    /// - Note: This method still performs full transcription internally but
    ///   only returns the text. For performance-critical applications where
    ///   you need both text and metadata, call `transcribe(...)` once and
    ///   access the properties you need.
    public func transcribeText<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        language: String? = nil
    ) async throws -> String {
        let config = TranscriptionConfig(
            language: language,
            wordTimestamps: false,
            format: .text
        )

        let result = try await provider.transcribe(
            audioURL: self,
            model: model,
            config: config
        )

        return result.text
    }

    // MARK: - Streaming Transcription

    /// Streams transcription segments from this URL as they become available.
    ///
    /// Provides incremental transcription results, yielding segments of the
    /// audio as they are processed. This is particularly useful for:
    /// - **Live Audio**: Real-time transcription of ongoing streams
    /// - **Long Recordings**: Processing large files with progressive results
    /// - **Interactive UI**: Displaying transcription as it happens
    /// - **Early Feedback**: Starting to process results before completion
    ///
    /// ## Usage
    /// ```swift
    /// let audioURL = URL(fileURLWithPath: "/path/to/lecture.mp3")
    ///
    /// for try await segment in audioURL.streamTranscription(
    ///     with: provider,
    ///     model: .whisper
    /// ) {
    ///     print("[\(segment.startTime)s - \(segment.endTime)s]: \(segment.text)")
    ///
    ///     // Update UI with segment
    ///     await updateTranscriptionView(with: segment)
    /// }
    ///
    /// print("Transcription complete!")
    /// ```
    ///
    /// ## Cancellation Support
    /// ```swift
    /// let transcriptionTask = Task {
    ///     for try await segment in audioURL.streamTranscription(
    ///         with: provider,
    ///         model: .whisper
    ///     ) {
    ///         print(segment.text)
    ///     }
    /// }
    ///
    /// // Cancel if needed
    /// transcriptionTask.cancel()
    /// ```
    ///
    /// ## Collecting All Segments
    /// ```swift
    /// var allSegments: [TranscriptionSegment] = []
    ///
    /// for try await segment in audioURL.streamTranscription(
    ///     with: provider,
    ///     model: .whisper
    /// ) {
    ///     allSegments.append(segment)
    /// }
    ///
    /// let fullText = allSegments.map(\.text).joined(separator: " ")
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The transcription provider to use.
    ///   - model: The model identifier for the provider's transcription model.
    ///   - config: Configuration options for transcription behavior.
    ///            Defaults to `.default`.
    ///
    /// - Returns: An `AsyncThrowingStream` that yields `TranscriptionSegment`
    ///            instances as they become available. The stream completes when
    ///            the entire audio file has been processed.
    ///
    /// - Note: The stream will throw errors if transcription fails at any point.
    ///   Use `try await` in the for-loop to handle errors appropriately.
    public func streamTranscription<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        config: TranscriptionConfig = .default
    ) -> AsyncThrowingStream<TranscriptionSegment, Error> {
        provider.streamTranscription(
            audioURL: self,
            model: model,
            config: config
        )
    }

    // MARK: - Subtitle Generation

    /// Transcribes audio from this URL and returns SRT subtitle format.
    ///
    /// SubRip (SRT) is a widely-supported subtitle format used by video players,
    /// editing software, and streaming platforms. This method transcribes the
    /// audio with word-level timestamps and exports it as SRT-formatted text.
    ///
    /// ## SRT Format
    /// SRT files contain numbered segments with timestamps and text:
    /// ```
    /// 1
    /// 00:00:00,000 --> 00:00:05,500
    /// Hello, welcome to this video.
    ///
    /// 2
    /// 00:00:05,500 --> 00:00:10,000
    /// Today we'll be discussing Swift.
    /// ```
    ///
    /// ## Usage
    /// ```swift
    /// let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
    /// let audioURL = extractAudio(from: videoURL)
    ///
    /// let srt = try await audioURL.transcribeToSRT(
    ///     with: provider,
    ///     model: .whisperLargeV3,
    ///     language: "en"
    /// )
    ///
    /// // Save to file
    /// let srtURL = videoURL.deletingPathExtension().appendingPathExtension("srt")
    /// try srt.write(to: srtURL, atomically: true, encoding: .utf8)
    /// ```
    ///
    /// ## Use Cases
    /// - Adding subtitles to videos
    /// - Creating accessibility captions
    /// - Generating transcripts for video content
    /// - Supporting multiple languages in video files
    ///
    /// - Parameters:
    ///   - provider: The transcription provider to use.
    ///   - model: The model identifier for the provider's transcription model.
    ///   - language: Optional language code (ISO 639-1). If `nil`, language
    ///              will be auto-detected. Default is `nil`.
    ///
    /// - Returns: A `String` containing the SRT-formatted subtitles, ready to
    ///            be written to a `.srt` file.
    ///
    /// - Throws: `AIError` if transcription fails.
    ///
    /// - SeeAlso: `transcribeToVTT` for WebVTT format
    /// - SeeAlso: `TranscriptionResult.toSRT()` for converting existing results
    public func transcribeToSRT<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        language: String? = nil
    ) async throws -> String {
        let config = TranscriptionConfig(
            language: language,
            wordTimestamps: true,
            format: .srt
        )

        let result = try await provider.transcribe(
            audioURL: self,
            model: model,
            config: config
        )

        return result.toSRT()
    }

    /// Transcribes audio from this URL and returns WebVTT subtitle format.
    ///
    /// WebVTT (Web Video Text Tracks) is a modern subtitle format designed for
    /// HTML5 video. It's the standard format for web-based video content and
    /// supports advanced features like styling and positioning.
    ///
    /// ## WebVTT Format
    /// WebVTT files start with "WEBVTT" and contain timestamped text cues:
    /// ```
    /// WEBVTT
    ///
    /// 1
    /// 00:00:00.000 --> 00:00:05.500
    /// Hello, welcome to this video.
    ///
    /// 2
    /// 00:00:05.500 --> 00:00:10.000
    /// Today we'll be discussing Swift.
    /// ```
    ///
    /// ## Usage
    /// ```swift
    /// let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
    /// let audioURL = extractAudio(from: videoURL)
    ///
    /// let vtt = try await audioURL.transcribeToVTT(
    ///     with: provider,
    ///     model: .whisperLargeV3,
    ///     language: "en"
    /// )
    ///
    /// // Save to file
    /// let vttURL = videoURL.deletingPathExtension().appendingPathExtension("vtt")
    /// try vtt.write(to: vttURL, atomically: true, encoding: .utf8)
    /// ```
    ///
    /// ## Web Integration
    /// ```html
    /// <video controls>
    ///     <source src="video.mp4" type="video/mp4">
    ///     <track src="subtitles.vtt" kind="subtitles" srclang="en" label="English">
    /// </video>
    /// ```
    ///
    /// ## Use Cases
    /// - HTML5 video subtitles
    /// - Web-based video platforms
    /// - Modern video players and frameworks
    /// - Accessibility for web content
    ///
    /// - Parameters:
    ///   - provider: The transcription provider to use.
    ///   - model: The model identifier for the provider's transcription model.
    ///   - language: Optional language code (ISO 639-1). If `nil`, language
    ///              will be auto-detected. Default is `nil`.
    ///
    /// - Returns: A `String` containing the WebVTT-formatted subtitles, ready
    ///            to be written to a `.vtt` file.
    ///
    /// - Throws: `AIError` if transcription fails.
    ///
    /// - SeeAlso: `transcribeToSRT` for SRT format
    /// - SeeAlso: `TranscriptionResult.toVTT()` for converting existing results
    public func transcribeToVTT<P: Transcriber>(
        with provider: P,
        model: P.ModelID,
        language: String? = nil
    ) async throws -> String {
        let config = TranscriptionConfig(
            language: language,
            wordTimestamps: true,
            format: .vtt
        )

        let result = try await provider.transcribe(
            audioURL: self,
            model: model,
            config: config
        )

        return result.toVTT()
    }
}
