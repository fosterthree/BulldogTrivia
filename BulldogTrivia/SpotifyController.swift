//  SpotifyController.swift
//  BulldogTrivia

//  Spotify playback control for trivia music questions.
//  Uses AppleScript to communicate with the Spotify desktop application.

//  Created by Asa Foster // 2026

import Foundation
import Combine
import OSLog
import AppKit

/// Controls Spotify playback for music trivia questions.
///
/// This controller communicates with the Spotify desktop application via AppleScript
/// to play, pause, and seek within tracks. It supports playing specific segments
/// of songs defined by start and stop times.
///
/// ## Requirements
/// - Spotify desktop application must be installed
/// - App must have AppleEvents/Automation permission
/// - App Sandbox must be disabled or have appropriate entitlements
///
/// ## Usage
/// ```swift
/// @StateObject private var spotify = SpotifyController()
///
/// // Play a track segment
/// spotify.playTrack(
///     url: "https://open.spotify.com/track/xxx",
///     startTime: "1:30",
///     stopTime: "1:45",
///     questionID: question.id
/// )
///
/// // Stop playback
/// spotify.pause()
/// ```
///
/// ## Thread Safety
/// All public methods are MainActor-isolated and safe to call from SwiftUI views.
@MainActor
class SpotifyController: ObservableObject {

// MARK: - Constants

private enum Constants {
    /// Polling interval in milliseconds for monitoring playback position.
    /// Reduced from 200ms to 1000ms to improve battery life and reduce CPU usage.
    static let pollingIntervalMs = 1000

    /// Buffer time in seconds before the stop time to account for timing variance.
    static let stopTimeBuffer: TimeInterval = 0.1
}

// MARK: - AppleScript Templates

/// AppleScript command templates for Spotify control.
private enum AppleScriptTemplates {
    /// Pauses Spotify playback.
    static let pause = "tell application \"Spotify\" to pause"

    /// Resumes Spotify playback.
    static let play = "tell application \"Spotify\" to play"

    /// Gets the current player position in seconds.
    static let getPosition = "tell application \"Spotify\" to return player position"

    /// Plays a track with seek. Use String interpolation for uri and startTime.
    /// Parameters: escapedURI (String), startTime (TimeInterval)
    static func playTrack(uri: String, startTime: TimeInterval) -> String {
        """
        tell application "Spotify"
            set savedVolume to sound volume
            set sound volume to 0
            play track "\(uri)"
            delay 0.5
            set player position to \(startTime)
            set sound volume to savedVolume
        end tell
        """
    }
}

// MARK: - Published Properties

/// Indicates whether Spotify is currently playing.
@Published var isPlaying = false

/// Current playback position in seconds.
@Published var currentPosition: TimeInterval = 0

/// Error message to display to the user, if any.
@Published var errorMessage: String?

/// The UUID of the question currently being played, or nil if nothing is playing.
@Published var currentlyPlayingQuestionID: UUID?

// MARK: - Private Properties

private var monitorTask: Task<Void, Never>?
private var stopTime: TimeInterval?
private let logger = AppLogger.spotify

deinit {
    monitorTask?.cancel()
}

// MARK: - Public Methods

/// Plays a Spotify track from startTime to stopTime.
///
/// The track will automatically pause when it reaches the stop time.
/// Any currently playing track will be stopped first.
///
/// - Parameters:
///   - url: Spotify URL (web URL or URI format).
///          Examples: `https://open.spotify.com/track/xxx` or `spotify:track:xxx`
///   - startTime: When to start playback (seconds as String, or "MM:SS" format).
///   - stopTime: When to stop playback (seconds as String, or "MM:SS" format).
///   - questionID: The UUID of the question being played, for tracking state.
///
/// ## Example
/// ```swift
/// spotify.playTrack(
///     url: "spotify:track:4iV5W9uYEdYUVa79Axb7Rh",
///     startTime: "90",      // 1:30 in seconds
///     stopTime: "1:45",     // MM:SS format
///     questionID: question.id
/// )
/// ```
func playTrack(url: String, startTime: String, stopTime: String, questionID: UUID) {
    logger.info("Attempting to play track: \(url, privacy: .public)")
    
    guard let uri = parseSpotifyURL(url) else {
        let error = TriviaError.invalidSpotifyURL(url)
        logger.log(error: error)
        errorMessage = error.localizedDescription
        return
    }
    
    guard let start = parseTime(startTime),
          let stop = parseTime(stopTime) else {
        let error = TriviaError.invalidTimeFormat("\(startTime) or \(stopTime)")
        logger.log(error: error)
        errorMessage = error.localizedDescription
        return
    }
    
    logger.debug("Parsed URI: \(uri, privacy: .public), start: \(start), stop: \(stop)")
    
    self.stopTime = stop
    self.currentlyPlayingQuestionID = questionID
    errorMessage = nil

    // Escape the URI to prevent AppleScript injection
    // Important: escape backslashes first, then quotes
    let escapedURI = uri.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")

    let script = AppleScriptTemplates.playTrack(uri: escapedURI, startTime: start)

    Task {
        // Stop any existing monitoring before starting new playback
        await stopMonitoringAsync()

        do {
            try await runAppleScript(script)
            logger.info("Playback started successfully")
            self.isPlaying = true
            self.startMonitoring()
        } catch {
            logger.error("Playback failed: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = "Failed to start playback: \(error.localizedDescription)"
            self.currentlyPlayingQuestionID = nil
        }
    }
}

/// Pauses Spotify playback.
///
/// This stops the current track and clears the playing state.
/// Safe to call even if nothing is playing.
func pause() {
    logger.info("Pausing playback")

    Task {
        do {
            try await runAppleScript(AppleScriptTemplates.pause)
            stopMonitoring()
            isPlaying = false
            currentlyPlayingQuestionID = nil
            errorMessage = nil
            logger.debug("Playback paused successfully")
        } catch {
            logger.error("Failed to pause: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to pause playback: \(error.localizedDescription)"
        }
    }
}

/// Resumes Spotify playback.
///
/// Continues playing from the current position.
/// The stop time monitoring will also resume.
func resume() {
    logger.info("Resuming playback")

    Task {
        do {
            try await runAppleScript(AppleScriptTemplates.play)
            startMonitoring()
            isPlaying = true
            errorMessage = nil
            logger.debug("Playback resumed successfully")
        } catch {
            logger.error("Failed to resume: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to resume playback: \(error.localizedDescription)"
        }
    }
}

/// Stops Spotify playback.
///
/// Alias for `pause()` for semantic clarity.
func stop() {
    pause()
}

/// Searches for a song on Spotify using the desktop app and retrieves the track URL.
///
/// Uses AppleScript to search Spotify for the given title and artist, then waits for
/// the user to play the desired track. Once playing, it captures the Spotify URI.
///
/// - Parameters:
///   - title: The song title to search for.
///   - artist: The artist name to search for.
///   - completion: Called with the Spotify URI when a track is detected, or nil on error.
///
/// ## Usage
/// ```swift
/// await spotify.searchAndGetTrackURL(title: "Bohemian Rhapsody", artist: "Queen") { uri in
///     if let uri = uri {
///         question.songURL = uri
///     }
/// }
/// ```
func searchAndGetTrackURL(title: String, artist: String, completion: @escaping (String?) -> Void) {
    logger.info("Searching for: \(title, privacy: .public) - \(artist, privacy: .public)")

    Task {
        // Step 1: Search iTunes API (free, no auth required)
        let query = "\(title) \(artist)".trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let iTunesURL = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&entity=song&limit=1") else {
            logger.warning("Invalid search query")
            await MainActor.run { completion(nil) }
            return
        }

        do {
            // Search iTunes
            let (iTunesData, _) = try await URLSession.shared.data(from: iTunesURL)
            guard let iTunesJSON = try JSONSerialization.jsonObject(with: iTunesData) as? [String: Any],
                  let results = iTunesJSON["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  let appleMusicURL = firstResult["trackViewUrl"] as? String else {
                logger.warning("No results found in iTunes")
                await MainActor.run { completion(nil) }
                return
            }

            logger.debug("Found Apple Music URL: \(appleMusicURL)")

            // Step 2: Convert Apple Music URL to Spotify using song.link
            guard let encodedAppleURL = appleMusicURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let songLinkURL = URL(string: "https://api.song.link/v1-alpha.1/links?url=\(encodedAppleURL)") else {
                logger.warning("Failed to create song.link URL")
                await MainActor.run { completion(nil) }
                return
            }

            let (songLinkData, _) = try await URLSession.shared.data(from: songLinkURL)
            guard let songLinkJSON = try JSONSerialization.jsonObject(with: songLinkData) as? [String: Any],
                  let linksByPlatform = songLinkJSON["linksByPlatform"] as? [String: Any],
                  let spotify = linksByPlatform["spotify"] as? [String: Any],
                  let spotifyURL = spotify["url"] as? String else {
                logger.warning("No Spotify URL found")
                await MainActor.run { completion(nil) }
                return
            }

            logger.info("Found Spotify URL: \(spotifyURL)")
            await MainActor.run { completion(spotifyURL) }

        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { completion(nil) }
        }
    }
}

/// Gets track metadata (title and artist) from a Spotify URL.
///
/// Opens the Spotify track in the desktop app and retrieves the song title and artist.
///
/// - Parameters:
///   - url: Spotify URL (web URL or URI format).
///   - completion: Called with (title, artist) tuple when metadata is retrieved, or nil on error.
///
/// ## Usage
/// ```swift
/// spotify.getTrackMetadata(url: "https://open.spotify.com/track/xxx") { metadata in
///     if let (title, artist) = metadata {
///         question.title = title
///         question.artist = artist
///     }
/// }
/// ```
func getTrackMetadata(url: String, completion: @escaping ((title: String, artist: String)?) -> Void) {
    guard let uri = parseSpotifyURL(url) else {
        logger.warning("Invalid Spotify URL for metadata retrieval: \(url)")
        completion(nil)
        return
    }

    logger.info("Fetching metadata for track: \(uri, privacy: .public)")

    // Extract track ID from URI
    guard uri.hasPrefix("spotify:track:") else {
        logger.warning("Invalid Spotify URI format: \(uri)")
        completion(nil)
        return
    }

    let trackID = String(uri.dropFirst("spotify:track:".count))

    // Get metadata without playing the track
    // Fetch metadata from Spotify's web page using URLSession
    Task {
        let webURL = "https://open.spotify.com/track/\(trackID)"

        guard let url = URL(string: webURL) else {
            logger.warning("Invalid web URL: \(webURL)")
            completion(nil)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                logger.warning("Failed to decode HTML")
                await MainActor.run { completion(nil) }
                return
            }

            // Extract title from HTML using regex
            // Title format: "<title>Song Title - Artist | Spotify</title>"
            let pattern = "<title>([^<]+)</title>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let titleRange = Range(match.range(at: 1), in: html) else {
                logger.warning("Failed to find title tag in HTML")
                await MainActor.run { completion(nil) }
                return
            }

            var pageTitle = String(html[titleRange])

            // Remove " | Spotify" suffix if present
            if let suffixRange = pageTitle.range(of: " | Spotify") {
                pageTitle = String(pageTitle[..<suffixRange.lowerBound])
            }

            logger.debug("Raw Spotify page title: \(pageTitle)")

            // Parse format: "Song Title - song and lyrics by Artist" or "Song Title - Artist"
            let components = pageTitle.components(separatedBy: " - ")
            if components.count >= 2 {
                var title = components[0].trimmingCharacters(in: .whitespacesAndNewlines)

                // Join remaining parts in case title contains " - "
                var artist = components[1...].joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove "song and lyrics by " prefix if present
                if let range = artist.range(of: "song and lyrics by ", options: .caseInsensitive) {
                    artist = String(artist[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Decode HTML entities
                title = decodeHTMLEntities(title)
                artist = decodeHTMLEntities(artist)

                logger.info("Parsed metadata - Title: '\(title)', Artist: '\(artist)'")

                await MainActor.run {
                    completion((title: title, artist: artist))
                }
            } else {
                logger.warning("Failed to parse metadata, unexpected format: \(pageTitle)")
                await MainActor.run {
                    completion(nil)
                }
            }
        } catch {
            logger.error("Failed to fetch track metadata: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                completion(nil)
            }
        }
    }
}

// MARK: - Private Methods

/// Executes an AppleScript string asynchronously.
/// Uses NSAppleScript for better performance than spawning Process.
///
/// - Parameter script: The AppleScript code to execute.
/// - Throws: An error if the script fails to execute.
private func runAppleScript(_ script: String) async throws {
    logger.debug("Executing AppleScript")

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            _ = appleScript?.executeAndReturnError(&error)

            if let error = error {
                let errorString = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                self?.logger.error("AppleScript error: \(errorString, privacy: .public)")
                continuation.resume(throwing: TriviaError.spotifyPlaybackFailed(errorString))
            } else {
                continuation.resume()
            }
        }
    }
}

/// Gets the current playback position from Spotify.
/// Uses NSAppleScript for better performance than spawning Process.
///
/// - Returns: The current position in seconds, or nil if unable to retrieve.
private func getPosition() async -> TimeInterval? {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: AppleScriptTemplates.getPosition)
            let result = appleScript?.executeAndReturnError(&error)

            if error != nil {
                self?.logger.debug("Failed to get position")
                continuation.resume(returning: nil)
            } else if let stringValue = result?.stringValue,
                      let seconds = Double(stringValue) {
                continuation.resume(returning: seconds)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

/// Starts monitoring playback position to auto-stop at the designated time.
private func startMonitoring() {
    stopMonitoring()

    logger.debug("Starting playback monitor")

    monitorTask = Task { [weak self] in
        while !Task.isCancelled {
            guard let self = self else {
                break
            }

            guard let stopTime = self.stopTime else {
                break
            }

            if let position = await self.getPosition() {
                await MainActor.run {
                    self.currentPosition = position
                }

                // Stop slightly before to account for timing variance
                if position >= stopTime - Constants.stopTimeBuffer {
                    await MainActor.run {
                        self.logger.info("Reached stop time, pausing")
                    }
                    do {
                        try await self.runAppleScript(AppleScriptTemplates.pause)
                    } catch {
                        await MainActor.run {
                            self.logger.error("Failed to auto-pause: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                    await MainActor.run {
                        self.isPlaying = false
                        self.currentlyPlayingQuestionID = nil
                    }
                    break
                }
            }

            try? await Task.sleep(for: .milliseconds(Constants.pollingIntervalMs))
        }
    }
}

/// Stops monitoring playback position and waits for cancellation.
private func stopMonitoring() {
    guard let task = monitorTask else { return }
    task.cancel()
    monitorTask = nil
    logger.debug("Playback monitor stopped")
}

/// Stops monitoring playback position asynchronously, waiting for the task to complete.
///
/// Use this when you need to ensure the monitoring task has fully stopped
/// before starting a new operation.
private func stopMonitoringAsync() async {
    guard let task = monitorTask else { return }
    task.cancel()
    _ = await task.value  // Wait for cancellation to complete
    monitorTask = nil
    logger.debug("Playback monitor stopped (async)")
}

/// Parses a Spotify URL or URI into the canonical URI format.
///
/// - Parameter url: A Spotify web URL or URI.
/// - Returns: The Spotify URI (e.g., "spotify:track:xxx"), or nil if invalid.
private func parseSpotifyURL(_ url: String) -> String? {
    TriviaValidator.canonicalSpotifyURI(from: url)
}

/// Parses a time string into seconds.
///
/// - Parameter timeString: Time as seconds ("90") or MM:SS format ("1:30").
/// - Returns: The time in seconds, or nil if the format is invalid.
private func parseTime(_ timeString: String) -> TimeInterval? {
    TriviaValidator.parseTimeToSeconds(timeString)
}
}

// MARK: - HTML Entity Decoding

/// Decodes HTML entities in a string (e.g., "&amp;" → "&")
private func decodeHTMLEntities(_ string: String) -> String {
    guard let data = string.data(using: .utf8) else { return string }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
    ]

    guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
        return string
    }

    return attributedString.string
}
