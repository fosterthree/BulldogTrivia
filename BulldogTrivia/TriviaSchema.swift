//  TriviaSchema.swift
//  BulldogTrivia

//  Pure Data Schema.
//  Strictly imports Foundation only.
//  Contains ONLY stored properties. No logic, no computed properties.

//  Created by Asa Foster // 2026

import Foundation

// MARK: - Schema Constants

/// Constants for trivia game data validation and constraints.
enum TriviaSchemaConstants {
    /// Maximum number of characters allowed in a crossword answer.
    static let crosswordMaxLetters: Int = 12

    /// Minimum allowed tiebreaker answer value.
    static let tiebreakerMinValue: Double = 0

    /// Maximum allowed tiebreaker answer value (1 billion).
    static let tiebreakerMaxValue: Double = 1_000_000_000
}

// MARK: - Root Data Wrapper

/// The root data structure for a trivia game document.
///
/// Contains all rounds and teams for a complete trivia game session.
/// This struct is the primary serialization target for `.trivia` files.
///
/// ## Serialization
/// `TriviaGameData` conforms to `Codable` and is serialized as JSON.
/// The document system handles encoding/decoding automatically.
///
/// ## Thread Safety
/// This struct is `Sendable` and can be safely passed across actor boundaries.
///
/// ## Example
/// ```swift
/// var gameData = TriviaGameData()
/// gameData.rounds.append(Round(name: "General Knowledge", format: .standard, questions: []))
/// gameData.teams.append(Team(name: "Quiz Masters"))
/// ```
struct TriviaGameData: Codable, Equatable, Sendable {
/// The rounds in this trivia game, in presentation order.
var rounds: [Round] = []

/// The teams participating in this trivia game.
var teams: [Team] = []
}

// MARK: - Team Model

/// Represents a team participating in a trivia game.
///
/// Teams track their scores per round and can have tiebreaker scores
/// for resolving ties in standings.
///
/// ## Scoring
/// Each team maintains a dictionary of scores keyed by round ID.
/// This allows scores to persist even if rounds are reordered.
///
/// ## Example
/// ```swift
/// var team = Team(name: "Brain Trust")
/// team.scores[round.id] = 15.5
/// team.tiebreakerScore = 42
/// ```
struct Team: Identifiable, Hashable, Codable, Sendable, Equatable {
/// Unique identifier for this team.
var id = UUID()

/// The display name of the team.
///
/// Should be unique within a game for clarity.
/// Maximum recommended length: 50 characters.
var name: String = ""

/// Scores for each round, keyed by round ID.
///
/// Values are typically whole numbers but support decimals
/// for half-point scoring systems.
var scores: [UUID: Double] = [:]

/// The team's answer to the tiebreaker question.
///
/// This is the raw numerical answer the team provided.
/// The winner is determined by closeness to the correct answer.
var tiebreakerAnswer: Double? = nil

/// The team's tiebreaker score for resolving tied standings.
///
/// - Note: This field is deprecated in favor of `tiebreakerAnswer`.
///   Kept for backwards compatibility with existing files.
///   When both fields exist, `tiebreakerAnswer` takes precedence.
var tiebreakerScore: Double = 0.0
}

// MARK: - Round Model

/// Represents a round in a trivia game.
///
/// A round contains a collection of questions and defines the format
/// for how those questions should be presented and scored.
///
/// ## Formats
/// - `.standard`: Traditional question and answer format
/// - `.music`: Audio-based questions with title/artist scoring
/// - `.crossword`: Letter-reveal style with clues
///
/// ## Example
/// ```swift
/// let round = Round(
///     name: "Pop Culture",
///     format: .standard,
///     questions: [
///         Question(format: .standard, text: "Who directed Jaws?", answer: "Steven Spielberg", points: 1.0)
///     ]
/// )
/// ```
struct Round: Identifiable, Hashable, Codable, Sendable, Equatable {
/// Unique identifier for this round.
var id = UUID()

/// The display name of the round.
///
/// Shown in the sidebar and on round title slides.
/// Maximum recommended length: 100 characters.
var name: String

/// The format of this round, determining question presentation.
var format: RoundFormat

/// The questions in this round, in presentation order.
var questions: [Question]
}

// MARK: - Question Model

/// Represents a single question in a trivia round.
///
/// Questions support multiple formats including standard Q&A, music identification,
/// crossword clues, connections, and tiebreakers.
///
/// ## Standard Questions
/// Use `text` for the question and `answer` for the expected response.
///
/// ## Music Questions
/// Use `title`, `artist`, `songURL`, `startTime`, and `stopTime`
/// for audio-based questions. Music questions use the shared `points`
/// field for scoring.
///
/// ## Crossword Questions
/// Use `text` for the clue, `answer` for the word, and `crosswordRevealIndex`
/// to specify which letter is initially revealed (1-based index).
///
/// ## Example
/// ```swift
/// // Standard question
/// let q1 = Question(format: .standard, text: "Capital of France?", answer: "Paris", points: 1.0)
///
/// // Music question
/// var q2 = Question(format: .musicQuestion, text: "", answer: "", points: 0)
/// q2.title = "Bohemian Rhapsody"
/// q2.artist = "Queen"
/// q2.songURL = "spotify:track:xxx"
/// q2.startTime = "0:55"
/// q2.stopTime = "1:10"
/// ```
struct Question: Identifiable, Hashable, Codable, Sendable, Equatable {
/// Unique identifier for this question.
var id = UUID()

/// The format/type of this question.
var format: QuestionFormat = .standard

// MARK: Standard / Tiebreaker Fields

/// The question text displayed to players.
///
/// For crossword format, this is the clue.
/// Maximum recommended length: 500 characters.
var text: String

/// The expected answer to the question.
///
/// For crossword format, must be a single word (no spaces) with max 12 characters.
/// Maximum recommended length: 200 characters for standard questions.
var answer: String

/// Points awarded for a correct answer.
///
/// Valid range: 0.0 to 10.0
/// Supports half-points (e.g., 1.5).
var points: Double

// MARK: Music Question Fields

/// The song title for music questions.
///
/// Maximum recommended length: 100 characters.
var title: String = ""

/// The artist name for music questions.
///
/// Maximum recommended length: 100 characters.
var artist: String = ""

/// Legacy points field retained for backwards compatibility with older files.
///
/// - Note: The app uses `points` for scoring.
var titlePoints: Double = 1.0

/// Legacy points field retained for backwards compatibility with older files.
///
/// - Note: The app uses `points` for scoring.
var artistPoints: Double = 1.0

/// Spotify URL or URI for the song.
///
/// Supports both web URLs (`https://open.spotify.com/track/xxx`)
/// and URIs (`spotify:track:xxx`).
var songURL: String = ""

/// Start time for the audio clip.
///
/// Format: seconds ("90") or MM:SS ("1:30").
var startTime: String = ""

/// Stop time for the audio clip.
///
/// Format: seconds ("90") or MM:SS ("1:30").
var stopTime: String = ""

// MARK: Crossword Clue Fields

/// The 1-based index/indices of letter(s) to reveal in crossword format.
///
/// Supports single values (e.g., "1") or comma-separated values (e.g., "1,5") for multiple reveals.
/// For example, if `answer` is "PARIS" and `crosswordRevealIndex` is "1,3",
/// the display would show "P _ R _ _".
///
/// Valid range for each index: 1 to answer.count
var crosswordRevealIndex: String? = "1"

// MARK: - Presenter Notes

/// Optional notes for the presenter.
///
/// These notes are only visible in the editor and can be used to provide
/// context, pronunciation guides, or other helpful information for the host.
var presenterNotes: String = ""

/// Whether presenter notes should be visible in the editor.
var showPresenterNotes: Bool = false

// MARK: - Initializers

init(
    format: QuestionFormat,
    text: String,
    answer: String,
    points: Double,
    title: String = "",
    artist: String = "",
    titlePoints: Double = 1.0,
    artistPoints: Double = 1.0,
    songURL: String = "",
    startTime: String = "",
    stopTime: String = "",
    crosswordRevealIndex: String? = "1"
) {
    self.format = format
    self.text = text
    self.answer = answer
    self.points = points
    self.title = title
    self.artist = artist
    self.titlePoints = titlePoints
    self.artistPoints = artistPoints
    self.songURL = songURL
    self.startTime = startTime
    self.stopTime = stopTime
    self.crosswordRevealIndex = crosswordRevealIndex
}

// MARK: - Codable Support

enum CodingKeys: String, CodingKey {
    case id, format, text, answer, points
    case title, artist, titlePoints, artistPoints
    case songURL, startTime, stopTime
    case crosswordRevealIndex
    case presenterNotes, showPresenterNotes
}

init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    format = try container.decode(QuestionFormat.self, forKey: .format)
    text = try container.decode(String.self, forKey: .text)
    answer = try container.decode(String.self, forKey: .answer)
    points = try container.decode(Double.self, forKey: .points)

    title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
    titlePoints = try container.decodeIfPresent(Double.self, forKey: .titlePoints) ?? 1.0
    artistPoints = try container.decodeIfPresent(Double.self, forKey: .artistPoints) ?? 1.0
    songURL = try container.decodeIfPresent(String.self, forKey: .songURL) ?? ""
    startTime = try container.decodeIfPresent(String.self, forKey: .startTime) ?? ""
    stopTime = try container.decodeIfPresent(String.self, forKey: .stopTime) ?? ""

    // Handle backward compatibility: Int -> String migration
    if let intValue = try? container.decode(Int.self, forKey: .crosswordRevealIndex) {
        crosswordRevealIndex = String(intValue)
    } else {
        crosswordRevealIndex = try container.decodeIfPresent(String.self, forKey: .crosswordRevealIndex) ?? "1"
    }

    // Handle backward compatibility: presenter notes (new fields)
    presenterNotes = try container.decodeIfPresent(String.self, forKey: .presenterNotes) ?? ""
    showPresenterNotes = try container.decodeIfPresent(Bool.self, forKey: .showPresenterNotes) ?? false
}

func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(format, forKey: .format)
    try container.encode(text, forKey: .text)
    try container.encode(answer, forKey: .answer)
    try container.encode(points, forKey: .points)

    try container.encode(title, forKey: .title)
    try container.encode(artist, forKey: .artist)
    try container.encode(titlePoints, forKey: .titlePoints)
    try container.encode(artistPoints, forKey: .artistPoints)
    try container.encode(songURL, forKey: .songURL)
    try container.encode(startTime, forKey: .startTime)
    try container.encode(stopTime, forKey: .stopTime)

    try container.encode(crosswordRevealIndex, forKey: .crosswordRevealIndex)

    try container.encode(presenterNotes, forKey: .presenterNotes)
    try container.encode(showPresenterNotes, forKey: .showPresenterNotes)
}
}

// MARK: - Round Format Enum

/// Defines the format/type of a trivia round.
///
/// The round format determines how questions are presented and what
/// fields are relevant for each question.
enum RoundFormat: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
/// Traditional question and answer format.
///
/// Questions use `text`, `answer`, and `points` fields.
case standard = "Standard Q&A"

/// Crossword-style format with letter reveals.
///
/// Questions use `text` (clue), `answer` (word), and `crosswordRevealIndex`.
case crossword = "Crossword"

/// Music identification format with audio playback.
///
/// Questions use `title`, `artist`, `songURL`, `startTime`, `stopTime`, and `points`.
case music = "Music"

/// Before & After format where two clues link through a common word/phrase.
///
/// Questions use `text` (clue 1), `artist` (clue 2), `answer` (combined answer), and `points`.
/// Example: "Canada's island province" + "Citizenfour subject" = "Prince Edward Snowden"
case beforeAndAfter = "Before & After"

var id: String { rawValue }
}

// MARK: - Question Format Enum

/// Defines the format/type of an individual question.
///
/// Most questions match their parent round's format, but rounds can contain
/// special question types like connections and tiebreakers.
enum QuestionFormat: String, CaseIterable, Identifiable, Hashable, Codable, Sendable, Equatable {
/// Standard question with text prompt and answer.
case standard = "Standard"

/// A connection question that links multiple answers.
///
/// Typically appears at the end of a round.
/// Uses only the `answer` field (the connection).
case connection = "Connection"

/// A tiebreaker question for resolving ties.
///
/// Usually a numerical estimation question.
/// Does not award points; instead updates `Team.tiebreakerScore`.
case tiebreaker = "Tiebreaker"

/// A music identification question with audio playback.
///
/// Uses `title`, `artist`, and audio fields.
case musicQuestion = "Music Question"

/// A crossword-style clue with letter reveal.
///
/// Uses `text` (clue), `answer`, and `crosswordRevealIndex`.
case crosswordClue = "Crossword Clue"

/// A Before & After question with two clues linking through a common word/phrase.
///
/// Uses `text` (clue 1), `artist` (clue 2), and `answer` (combined answer).
case beforeAndAfter = "Before & After"

var id: String { rawValue }
}
