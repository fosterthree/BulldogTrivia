//  SpotifyController.swift
//  BulldogTrivia

//  Spotify playback control for trivia music questions.
//  Uses AppleScript to communicate with the Spotify desktop application.

//  Created by Asa Foster // 2026

import Foundation
import Combine
import OSLog
import AppKit
import CommonCrypto

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
    static let pollingIntervalMs = 200

    /// Buffer time in seconds before the stop time to account for timing variance.
    static let stopTimeBuffer: TimeInterval = 0.1

    /// Maximum length for Spotify track IDs (base62 encoded).
    static let maxTrackIDLength = 30
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

// MARK: - Spotify API Properties

/// Spotify API access token
private var accessToken: String?

/// Token expiration date
private var tokenExpirationDate: Date?

/// Spotify API client ID (register at https://developer.spotify.com/dashboard)
private let clientID = "YOUR_CLIENT_ID" // TODO: Replace with actual client ID

/// Redirect URI for OAuth callback
private let redirectURI = "bulldogtrivia://spotify-callback"

// MARK: - Published Properties

/// Indicates whether Spotify is currently playing.
@Published var isPlaying = false

/// Current playback position in seconds.
@Published var currentPosition: TimeInterval = 0

/// Error message to display to the user, if any.
@Published var errorMessage: String?

/// Whether user is authenticated with Spotify API
@Published var isAuthenticated = false

/// The UUID of the question currently being played, or nil if nothing is playing.
@Published var currentlyPlayingQuestionID: UUID?

// MARK: - Private Properties

private var monitorTask: Task<Void, Never>?
private var stopTime: TimeInterval?
private let logger = AppLogger.spotify

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

/// Executes an AppleScript and returns the result as a String.
private func getSpotifyScriptResult(script: String) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.terminationHandler = { process in
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let result = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !result.isEmpty {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: nil)
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"

                let error = TriviaError.spotifyPlaybackFailed(errorString)
                continuation.resume(throwing: error)
            }
        }

        do {
            try process.run()
        } catch {
            continuation.resume(throwing: TriviaError.spotifyPlaybackFailed(error.localizedDescription))
        }
    }
}

/// Gets the current track URI from Spotify using AppleScript.
private func getSpotifyCurrentTrackURI(script: String) async throws -> String? {
    try await getSpotifyScriptResult(script: script)
}

// MARK: - Private Methods

/// Executes an AppleScript string asynchronously.
///
/// - Parameter script: The AppleScript code to execute.
/// - Throws: An error if the script fails to execute.
private func runAppleScript(_ script: String) async throws {
    logger.debug("Executing AppleScript")
    
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        
        process.terminationHandler = { [weak self] process in
            if process.terminationStatus == 0 {
                continuation.resume()
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
                
                self?.logger.error("AppleScript error: \(errorString, privacy: .public)")
                
                let error = TriviaError.spotifyPlaybackFailed(errorString)
                continuation.resume(throwing: error)
            }
        }
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to run process: \(error.localizedDescription, privacy: .public)")
            continuation.resume(throwing: TriviaError.spotifyPlaybackFailed(error.localizedDescription))
        }
    }
}

/// Gets the current playback position from Spotify.
///
/// - Returns: The current position in seconds, or nil if unable to retrieve.
private func getPosition() async -> TimeInterval? {
    await withCheckedContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", AppleScriptTemplates.getPosition]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        
        process.terminationHandler = { process in
            guard process.terminationStatus == 0 else {
                continuation.resume(returning: nil)
                return
            }
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let seconds = Double(result) {
                continuation.resume(returning: seconds)
            } else {
                continuation.resume(returning: nil)
            }
        }
        
        do {
            try process.run()
        } catch {
            logger.debug("Failed to get position: \(error.localizedDescription, privacy: .public)")
            continuation.resume(returning: nil)
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
    let trimmed = url.trimmingCharacters(in: .whitespaces)
    
    // Already a URI
    if trimmed.hasPrefix("spotify:track:") {
        // Validate it only contains safe characters
        let trackID = String(trimmed.dropFirst("spotify:track:".count))
        if isValidTrackID(trackID) {
            return trimmed
        }
        return nil
    }
    
    // Web URL format
    if trimmed.contains("open.spotify.com/track/") {
        if let trackID = trimmed.components(separatedBy: "/track/").last?
            .components(separatedBy: "?").first?
            .trimmingCharacters(in: .whitespaces),
           isValidTrackID(trackID) {
            return "spotify:track:\(trackID)"
        }
    }
    
    return nil
}

/// Validates that a track ID contains only safe characters.
///
/// - Parameter trackID: The Spotify track ID to validate.
/// - Returns: True if the track ID is valid.
private func isValidTrackID(_ trackID: String) -> Bool {
    // Spotify track IDs are base62 encoded (alphanumeric only)
    let allowedCharacters = CharacterSet.alphanumerics
    return trackID.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
        && !trackID.isEmpty
        && trackID.count <= Constants.maxTrackIDLength
}

/// Parses a time string into seconds.
///
/// - Parameter timeString: Time as seconds ("90") or MM:SS format ("1:30").
/// - Returns: The time in seconds, or nil if the format is invalid.
private func parseTime(_ timeString: String) -> TimeInterval? {
    let trimmed = timeString.trimmingCharacters(in: .whitespaces)
    
    // Format: "90" (seconds only)
    if let seconds = Double(trimmed), seconds >= 0 {
        return seconds
    }
    
    // Format: "1:30" or "01:30" (MM:SS)
    let components = trimmed.components(separatedBy: ":")
    if components.count == 2,
       let minutes = Double(components[0]),
       let seconds = Double(components[1]),
       minutes >= 0, seconds >= 0, seconds < 60 {
        return (minutes * 60) + seconds
    }
    
    return nil
}

// MARK: - Spotify API Authentication

/// Initiates Spotify OAuth authentication flow using PKCE
func authenticate() {
    Task {
        do {
            // Generate PKCE code verifier and challenge
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)

            // Store code verifier for later use
            UserDefaults.standard.set(codeVerifier, forKey: "spotify_code_verifier")

            // Build authorization URL
            var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "scope", value: "user-read-private user-read-email")
            ]

            guard let authURL = components.url else {
                logger.error("Failed to create authorization URL")
                return
            }

            // Open authorization URL in browser
            await MainActor.run {
                NSWorkspace.shared.open(authURL)
            }
        } catch {
            logger.error("Authentication failed: \(error.localizedDescription)")
        }
    }
}

/// Handles the OAuth callback with authorization code
func handleCallback(code: String) {
    Task {
        guard let codeVerifier = UserDefaults.standard.string(forKey: "spotify_code_verifier") else {
            logger.error("No code verifier found")
            return
        }

        // Exchange authorization code for access token
        var components = URLComponents(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]

        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)

            await MainActor.run {
                self.accessToken = response.access_token
                self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(response.expires_in))
                self.isAuthenticated = true
                UserDefaults.standard.removeObject(forKey: "spotify_code_verifier")
            }

            logger.info("Successfully authenticated with Spotify")
        } catch {
            logger.error("Token exchange failed: \(error.localizedDescription)")
        }
    }
}

/// Generates a random code verifier for PKCE
private func generateCodeVerifier() -> String {
    var buffer = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
    return Data(buffer).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
        .trimmingCharacters(in: .whitespaces)
}

/// Generates a code challenge from a code verifier
private func generateCodeChallenge(from verifier: String) -> String {
    guard let data = verifier.data(using: .utf8) else { return "" }
    var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
    }
    return Data(buffer).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
        .trimmingCharacters(in: .whitespaces)
}

/// Checks if the access token is still valid
private var isTokenValid: Bool {
    guard let expirationDate = tokenExpirationDate else { return false }
    return Date() < expirationDate
}
}

// MARK: - Spotify API Response Models

private struct SpotifyTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
}

private struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTracks
}

private struct SpotifyTracks: Codable {
    let items: [SpotifyTrack]
}

private struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let external_urls: SpotifyExternalURLs
}

private struct SpotifyArtist: Codable {
    let name: String
}

private struct SpotifyExternalURLs: Codable {
    let spotify: String
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
