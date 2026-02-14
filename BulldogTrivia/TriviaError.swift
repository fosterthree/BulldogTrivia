//  TriviaError.swift
//  BulldogTrivia

//  Unified error handling for the application.
//  Provides localized error descriptions and recovery suggestions.

//  Created by Asa Foster // 2026

import Foundation

/// Comprehensive error type for all BulldogTrivia errors.
///
/// `TriviaError` provides user-friendly error messages with recovery suggestions,
/// making it suitable for display in alerts and error views.
///
/// ## Error Categories
/// - **Spotify Errors**: Issues with Spotify integration and playback
/// - **Document Errors**: File I/O and corruption issues
/// - **Validation Errors**: Invalid user input
/// - **Presentation Errors**: Slide generation and display issues
///
/// ## Usage
/// ```swift
/// do {
///     try someOperation()
/// } catch {
///     if let triviaError = error as? TriviaError {
///         showAlert(
///             title: "Error",
///             message: triviaError.localizedDescription,
///             suggestion: triviaError.recoverySuggestion
///         )
///     }
/// }
/// ```
///
/// ## Logging Integration
/// Use with `AppLogger` for consistent error logging:
/// ```swift
/// AppLogger.document.log(error: triviaError)
/// ```
enum TriviaError: LocalizedError, Equatable {

// MARK: - Spotify Errors

/// The provided Spotify URL is not in a recognized format.
///
/// - Parameter url: The invalid URL that was provided.
case invalidSpotifyURL(String)

/// Spotify application is not running or not accessible.
case spotifyNotRunning

/// Spotify playback failed for the specified reason.
///
/// - Parameter reason: Description of why playback failed.
case spotifyPlaybackFailed(String)

/// The time format string could not be parsed.
///
/// - Parameter time: The invalid time string.
case invalidTimeFormat(String)

// MARK: - Document Errors

/// The document file is corrupted or in an invalid format.
///
/// - Parameter reason: Description of the corruption.
case documentCorrupted(String)

/// Failed to save the document to disk.
///
/// - Parameter reason: Description of why the save failed.
case documentSaveFailed(String)

/// Failed to load the document from disk.
///
/// - Parameter reason: Description of why the load failed.
case documentLoadFailed(String)

// MARK: - Validation Errors

/// Round name is empty or contains only whitespace.
case emptyRoundName

/// Team name is empty or contains only whitespace.
case emptyTeamName

/// Multiple teams have the same name.
///
/// - Parameter names: The duplicate team names found.
case duplicateTeamNames([String])

/// One or more rounds have no questions.
///
/// - Parameter count: The number of empty rounds.
case emptyRoundsDetected(Int)

/// Crossword answer exceeds the maximum allowed length.
///
/// - Parameters:
///   - answer: The answer that is too long.
///   - maxLength: The maximum allowed length.
case crosswordAnswerTooLong(String, Int)

/// Crossword answer contains spaces, which are not allowed.
///
/// - Parameter answer: The answer containing spaces.
case crosswordAnswerContainsSpaces(String)

/// Point value is outside the valid range (0-10) or not in half-point increments.
///
/// - Parameter value: The invalid point value.
case invalidPointValue(Double)

// MARK: - Presentation Errors

/// No slides were generated, likely due to empty game data.
case noSlidesGenerated

/// Attempted to navigate to an invalid slide index.
///
/// - Parameters:
///   - requested: The requested slide index.
///   - max: The maximum valid index.
case invalidSlideIndex(Int, Int)

/// Failed to open the presentation window.
case presentationWindowFailed

// MARK: - LocalizedError Conformance

var errorDescription: String? {
    switch self {
    case .invalidSpotifyURL(let url):
        return "Invalid Spotify URL: '\(url)'. Please use a Spotify track URL or URI."
    case .spotifyNotRunning:
        return "Spotify is not running. Please open Spotify and try again."
    case .spotifyPlaybackFailed(let reason):
        return "Spotify playback failed: \(reason)"
    case .invalidTimeFormat(let time):
        return "Invalid time format '\(time)'. Use seconds (90) or MM:SS (1:30)."
        
    case .documentCorrupted(let reason):
        return "The document is corrupted: \(reason)"
    case .documentSaveFailed(let reason):
        return "Failed to save document: \(reason)"
    case .documentLoadFailed(let reason):
        return "Failed to load document: \(reason)"
        
    case .emptyRoundName:
        return "Round name cannot be empty."
    case .emptyTeamName:
        return "Team name cannot be empty."
    case .duplicateTeamNames(let names):
        return "Duplicate team names found: \(names.joined(separator: ", "))"
    case .emptyRoundsDetected(let count):
        return "\(count) round(s) have no questions. Consider adding questions or removing empty rounds."
    case .crosswordAnswerTooLong(let answer, let maxLength):
        return "Crossword answer '\(answer)' is too long. Maximum \(maxLength) characters allowed."
    case .crosswordAnswerContainsSpaces(let answer):
        return "Crossword answer '\(answer)' cannot contain spaces."
    case .invalidPointValue(let value):
        return "Invalid point value: \(value). Points must be 0-10 in 0.5 increments."
        
    case .noSlidesGenerated:
        return "No slides were generated. Please add rounds and questions first."
    case .invalidSlideIndex(let requested, let max):
        return "Invalid slide index \(requested). Valid range is 0-\(max)."
    case .presentationWindowFailed:
        return "Failed to open presentation window."
    }
}

var recoverySuggestion: String? {
    switch self {
    case .invalidSpotifyURL:
        return "Copy the URL from Spotify by right-clicking a track and selecting 'Share > Copy Song Link'."
    case .spotifyNotRunning:
        return "Open the Spotify application on your Mac."
    case .spotifyPlaybackFailed:
        return "Check that Spotify is playing correctly and try again."
    case .invalidTimeFormat:
        return "Enter time as total seconds (e.g., 90) or as minutes:seconds (e.g., 1:30)."
        
    case .documentCorrupted:
        return "Try opening a backup or creating a new document."
    case .documentSaveFailed:
        return "Check that you have write permissions and enough disk space."
    case .documentLoadFailed:
        return "Ensure the file exists and is a valid .trivia file."
        
    case .emptyRoundName:
        return "Enter a name for the round."
    case .emptyTeamName:
        return "Enter a name for each team."
    case .duplicateTeamNames:
        return "Give each team a unique name."
    case .emptyRoundsDetected:
        return "Add questions to empty rounds or delete them."
    case .crosswordAnswerTooLong:
        return "Use a shorter answer or abbreviation."
    case .crosswordAnswerContainsSpaces:
        return "Crossword answers must be single words without spaces."
    case .invalidPointValue:
        return "Enter a point value from 0 to 10 in half-point increments (for example: 1, 1.5, 2)."
        
    case .noSlidesGenerated:
        return "Add at least one round with questions to start the presentation."
    case .invalidSlideIndex:
        return "Navigate to a valid slide."
    case .presentationWindowFailed:
        return "Try starting the presentation again."
    }
}

var failureReason: String? {
    switch self {
    case .invalidSpotifyURL:
        return "The URL format was not recognized."
    case .spotifyNotRunning:
        return "AppleScript could not communicate with Spotify."
    case .spotifyPlaybackFailed(let reason):
        return reason
    case .invalidTimeFormat:
        return "The time string could not be parsed."
        
    case .documentCorrupted(let reason):
        return reason
    case .documentSaveFailed(let reason):
        return reason
    case .documentLoadFailed(let reason):
        return reason
        
    default:
        return nil
    }
}
}

// MARK: - Validation Helpers

/// Utility functions for validating trivia game data.
///
/// Use these validators to check user input before saving or presenting.
/// Each validator returns an optional `TriviaError` - nil means valid.
///
/// ## Usage
/// ```swift
/// if let error = TriviaValidator.validateTeamName(name) {
///     AppLogger.validation.log(error: error)
///     showError(error)
///     return
/// }
/// ```
///
/// ## Batch Validation
/// For validating entire documents, combine multiple validators:
/// ```swift
/// let errors = [
///     TriviaValidator.validateTeamsForDuplicates(teams),
///     TriviaValidator.validateRoundsForEmptyQuestions(rounds)
/// ].compactMap { $0 }
/// ```
struct TriviaValidator {

private static let spotifyTrackPrefix = "spotify:track:"
private static let maxSpotifyTrackIDLength = 30

// MARK: - Single Value Validators

/// Validates that a team name is not empty.
///
/// - Parameter name: The team name to validate.
/// - Returns: `TriviaError.emptyTeamName` if invalid, nil if valid.
static func validateTeamName(_ name: String) -> TriviaError? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .emptyTeamName
    }
    return nil
}

/// Validates that a round name is not empty.
///
/// - Parameter name: The round name to validate.
/// - Returns: `TriviaError.emptyRoundName` if invalid, nil if valid.
static func validateRoundName(_ name: String) -> TriviaError? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .emptyRoundName
    }
    return nil
}

/// Validates that a crossword answer meets format requirements.
///
/// Crossword answers must be:
/// - 12 characters or fewer
/// - Single words (no spaces)
///
/// - Parameter answer: The crossword answer to validate.
/// - Returns: The appropriate `TriviaError` if invalid, nil if valid.
static func validateCrosswordAnswer(_ answer: String) -> TriviaError? {
    let maxLength = TriviaSchemaConstants.crosswordMaxLetters

    if answer.count > maxLength {
        return .crosswordAnswerTooLong(answer, maxLength)
    }
    if answer.contains(" ") {
        return .crosswordAnswerContainsSpaces(answer)
    }
    return nil
}

/// Validates that a point value is within the allowed range and in half-point increments.
///
/// Points must be between 0 and 10, inclusive, and must be a multiple of 0.5.
///
/// - Parameter points: The point value to validate.
/// - Returns: `TriviaError.invalidPointValue` if invalid, nil if valid.
static func validatePoints(_ points: Double) -> TriviaError? {
    if points < 0 || points > 10 {
        return .invalidPointValue(points)
    }

    let halfPointUnits = points * 2
    if abs(halfPointUnits.rounded() - halfPointUnits) > 0.000_001 {
        return .invalidPointValue(points)
    }
    return nil
}

// MARK: - Collection Validators

/// Validates that all team names are unique.
///
/// Comparison is case-insensitive and ignores leading/trailing whitespace.
///
/// - Parameter teams: The array of teams to validate.
/// - Returns: `TriviaError.duplicateTeamNames` if duplicates found, nil if valid.
static func validateTeamsForDuplicates(_ teams: [Team]) -> TriviaError? {
    let names = teams.map { $0.name.lowercased().trimmingCharacters(in: .whitespaces) }
    let uniqueNames = Set(names)
    
    if names.count != uniqueNames.count {
        // Find duplicates
        var seen = Set<String>()
        var duplicates = [String]()
        for name in names {
            if seen.contains(name) && !duplicates.contains(name) {
                duplicates.append(name)
            }
            seen.insert(name)
        }
        return .duplicateTeamNames(duplicates)
    }
    return nil
}

/// Validates that all rounds have at least one question.
///
/// - Parameter rounds: The array of rounds to validate.
/// - Returns: `TriviaError.emptyRoundsDetected` if empty rounds found, nil if valid.
static func validateRoundsForEmptyQuestions(_ rounds: [Round]) -> TriviaError? {
    let emptyRounds = rounds.filter { $0.questions.isEmpty }
    if !emptyRounds.isEmpty {
        return .emptyRoundsDetected(emptyRounds.count)
    }
    return nil
}

// MARK: - Format Validators

/// Parses a Spotify URL or URI into canonical URI format (`spotify:track:<id>`).
static func canonicalSpotifyURI(from url: String) -> String? {
    let trimmed = url.trimmingCharacters(in: .whitespaces)

    if trimmed.hasPrefix(spotifyTrackPrefix) {
        let trackID = String(trimmed.dropFirst(spotifyTrackPrefix.count))
        return isValidSpotifyTrackID(trackID) ? trimmed : nil
    }

    if trimmed.contains("open.spotify.com/track/"),
       let trackID = trimmed.components(separatedBy: "/track/").last?
        .components(separatedBy: "?").first?
        .trimmingCharacters(in: .whitespaces),
       isValidSpotifyTrackID(trackID) {
        return "\(spotifyTrackPrefix)\(trackID)"
    }

    return nil
}

/// Parses a time string into seconds, supporting both `SS` and `MM:SS`.
static func parseTimeToSeconds(_ time: String) -> TimeInterval? {
    let trimmed = time.trimmingCharacters(in: .whitespaces)

    if let seconds = Double(trimmed), seconds >= 0 {
        return seconds
    }

    let components = trimmed.components(separatedBy: ":")
    if components.count == 2,
       let minutes = Double(components[0]),
       let seconds = Double(components[1]),
       minutes >= 0, seconds >= 0, seconds < 60 {
        return (minutes * 60) + seconds
    }

    return nil
}

private static func isValidSpotifyTrackID(_ trackID: String) -> Bool {
    let allowedCharacters = CharacterSet.alphanumerics
    return !trackID.isEmpty
        && trackID.count <= maxSpotifyTrackIDLength
        && trackID.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
}

/// Validates that a Spotify URL is in a recognized format.
///
/// Accepts:
/// - Spotify URIs: `spotify:track:xxx`
/// - Web URLs: `https://open.spotify.com/track/xxx`
///
/// Empty strings are considered valid (no URL set yet).
///
/// - Parameter url: The Spotify URL to validate.
/// - Returns: `TriviaError.invalidSpotifyURL` if invalid format, nil if valid.
static func validateSpotifyURL(_ url: String) -> TriviaError? {
    let trimmed = url.trimmingCharacters(in: .whitespaces)
    
    if trimmed.isEmpty {
        return nil // Empty is allowed (just means no URL set)
    }

    return canonicalSpotifyURI(from: trimmed) == nil ? .invalidSpotifyURL(url) : nil
}

/// Validates that a time string is in a recognized format.
///
/// Accepts:
/// - Seconds: `"90"`
/// - MM:SS: `"1:30"` or `"01:30"`
///
/// Empty strings are considered valid (no time set yet).
///
/// - Parameter time: The time string to validate.
/// - Returns: `TriviaError.invalidTimeFormat` if invalid format, nil if valid.
static func validateTimeFormat(_ time: String) -> TriviaError? {
    let trimmed = time.trimmingCharacters(in: .whitespaces)
    
    if trimmed.isEmpty {
        return nil // Empty is allowed
    }

    return parseTimeToSeconds(trimmed) == nil ? .invalidTimeFormat(time) : nil
}

// MARK: - Comprehensive Validation

/// Validates an entire game document and returns all errors found.
///
/// This performs comprehensive validation including:
/// - Team name uniqueness
/// - Empty round detection
/// - Crossword answer validation
/// - Point value validation
///
/// - Parameter gameData: The game data to validate.
/// - Returns: An array of all validation errors found (empty if valid).
static func validateGameData(_ gameData: TriviaGameData) -> [TriviaError] {
    var errors: [TriviaError] = []
    
    // Validate teams
    if let error = validateTeamsForDuplicates(gameData.teams) {
        errors.append(error)
    }
    
    for team in gameData.teams {
        if let error = validateTeamName(team.name) {
            errors.append(error)
        }
    }
    
    // Validate rounds
    if let error = validateRoundsForEmptyQuestions(gameData.rounds) {
        errors.append(error)
    }
    
    for round in gameData.rounds {
        if let error = validateRoundName(round.name) {
            errors.append(error)
        }
        
        // Validate questions
        for question in round.questions {
            if let error = validatePoints(question.points) {
                errors.append(error)
            }
            
            if question.format == .crosswordClue {
                if let error = validateCrosswordAnswer(question.answer) {
                    errors.append(error)
                }
            }
            
            if question.format == .musicQuestion {
                if let error = validateSpotifyURL(question.songURL) {
                    errors.append(error)
                }
                if let error = validateTimeFormat(question.startTime) {
                    errors.append(error)
                }
                if let error = validateTimeFormat(question.stopTime) {
                    errors.append(error)
                }
            }
        }
    }
    
    return errors
}
}
