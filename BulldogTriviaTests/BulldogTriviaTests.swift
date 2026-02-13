//  BulldogTriviaTests.swift
//  BulldogTriviaTests

//  Unit tests for TriviaValidator and scoring logic.

//  Created by Asa Foster // 2026

import XCTest
@testable import BulldogTrivia

// MARK: - TriviaValidator Tests

final class TriviaValidatorTests: XCTestCase {

// MARK: - Team Name Validation

func testEmptyTeamNameReturnsError() {
    let result = TriviaValidator.validateTeamName("")
    XCTAssertEqual(result, .emptyTeamName)
}

func testWhitespaceTeamNameReturnsError() {
    let result = TriviaValidator.validateTeamName("   ")
    XCTAssertEqual(result, .emptyTeamName)
}

func testValidTeamNameReturnsNil() {
    let result = TriviaValidator.validateTeamName("Quiz Masters")
    XCTAssertNil(result)
}

// MARK: - Round Name Validation

func testEmptyRoundNameReturnsError() {
    let result = TriviaValidator.validateRoundName("")
    XCTAssertEqual(result, .emptyRoundName)
}

func testValidRoundNameReturnsNil() {
    let result = TriviaValidator.validateRoundName("General Knowledge")
    XCTAssertNil(result)
}

// MARK: - Crossword Answer Validation

func testLongCrosswordAnswerReturnsError() {
    let result = TriviaValidator.validateCrosswordAnswer("EXTRAORDINARY")
    XCTAssertEqual(result, .crosswordAnswerTooLong("EXTRAORDINARY", 12))
}

func testCrosswordAnswerWithSpacesReturnsError() {
    let result = TriviaValidator.validateCrosswordAnswer("NEW YORK")
    XCTAssertEqual(result, .crosswordAnswerContainsSpaces("NEW YORK"))
}

func testValidCrosswordAnswerReturnsNil() {
    let result = TriviaValidator.validateCrosswordAnswer("PARIS")
    XCTAssertNil(result)
}

func testMaxLengthCrosswordAnswerIsValid() {
    let result = TriviaValidator.validateCrosswordAnswer("ABCDEFGHIJKL")
    XCTAssertNil(result)
}

// MARK: - Points Validation

func testNegativePointsReturnsError() {
    let result = TriviaValidator.validatePoints(-1.0)
    XCTAssertEqual(result, .invalidPointValue(-1.0))
}

func testHighPointsReturnsError() {
    let result = TriviaValidator.validatePoints(11.0)
    XCTAssertEqual(result, .invalidPointValue(11.0))
}

func testZeroPointsIsValid() {
    let result = TriviaValidator.validatePoints(0.0)
    XCTAssertNil(result)
}

func testTenPointsIsValid() {
    let result = TriviaValidator.validatePoints(10.0)
    XCTAssertNil(result)
}

func testHalfPointsIsValid() {
    let result = TriviaValidator.validatePoints(1.5)
    XCTAssertNil(result)
}

// MARK: - Duplicate Team Validation

func testDuplicateTeamNamesReturnsError() {
    let teams = [
        Team(name: "Quiz Masters"),
        Team(name: "Brain Trust"),
        Team(name: "quiz masters")  // Case-insensitive duplicate
    ]
    let result = TriviaValidator.validateTeamsForDuplicates(teams)
    XCTAssertEqual(result, .duplicateTeamNames(["quiz masters"]))
}

func testUniqueTeamNamesReturnsNil() {
    let teams = [
        Team(name: "Quiz Masters"),
        Team(name: "Brain Trust"),
        Team(name: "Trivia Titans")
    ]
    let result = TriviaValidator.validateTeamsForDuplicates(teams)
    XCTAssertNil(result)
}

// MARK: - Empty Rounds Validation

func testEmptyRoundsReturnsError() {
    let rounds = [
        Round(name: "Round 1", format: .standard, questions: []),
        Round(name: "Round 2", format: .standard, questions: [
            Question(format: .standard, text: "Q1", answer: "A1", points: 1.0)
        ])
    ]
    let result = TriviaValidator.validateRoundsForEmptyQuestions(rounds)
    XCTAssertEqual(result, .emptyRoundsDetected(1))
}

func testRoundsWithQuestionsReturnsNil() {
    let rounds = [
        Round(name: "Round 1", format: .standard, questions: [
            Question(format: .standard, text: "Q1", answer: "A1", points: 1.0)
        ])
    ]
    let result = TriviaValidator.validateRoundsForEmptyQuestions(rounds)
    XCTAssertNil(result)
}

// MARK: - Spotify URL Validation

func testValidSpotifyURIReturnsNil() {
    let result = TriviaValidator.validateSpotifyURL("spotify:track:4iV5W9uYEdYUVa79Axb7Rh")
    XCTAssertNil(result)
}

func testValidSpotifyWebURLReturnsNil() {
    let result = TriviaValidator.validateSpotifyURL("https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh")
    XCTAssertNil(result)
}

func testEmptySpotifyURLReturnsNil() {
    let result = TriviaValidator.validateSpotifyURL("")
    XCTAssertNil(result)
}

func testInvalidSpotifyURLReturnsError() {
    let result = TriviaValidator.validateSpotifyURL("https://youtube.com/watch?v=xxx")
    XCTAssertEqual(result, .invalidSpotifyURL("https://youtube.com/watch?v=xxx"))
}

func testSpotifyURLWithInvalidTrackIDReturnsError() {
    let result = TriviaValidator.validateSpotifyURL("spotify:track:invalid-id")
    XCTAssertEqual(result, .invalidSpotifyURL("spotify:track:invalid-id"))
}

// MARK: - Time Format Validation

func testSecondsFormatIsValid() {
    let result = TriviaValidator.validateTimeFormat("90")
    XCTAssertNil(result)
}

func testMMSSFormatIsValid() {
    let result = TriviaValidator.validateTimeFormat("1:30")
    XCTAssertNil(result)
}

func testEmptyTimeIsValid() {
    let result = TriviaValidator.validateTimeFormat("")
    XCTAssertNil(result)
}

func testInvalidTimeFormatReturnsError() {
    let result = TriviaValidator.validateTimeFormat("invalid")
    XCTAssertEqual(result, .invalidTimeFormat("invalid"))
}

func testMMSSFormatWithInvalidSecondsReturnsError() {
    let result = TriviaValidator.validateTimeFormat("1:75")
    XCTAssertEqual(result, .invalidTimeFormat("1:75"))
}

func testNegativeTimeReturnsError() {
    let result = TriviaValidator.validateTimeFormat("-5")
    XCTAssertEqual(result, .invalidTimeFormat("-5"))
}
}

// MARK: - Team Scoring Tests

final class TeamScoringTests: XCTestCase {

func testTotalScoreSumsAllRounds() {
    let round1 = Round(name: "R1", format: .standard, questions: [])
    let round2 = Round(name: "R2", format: .standard, questions: [])
    let rounds = [round1, round2]
    
    var team = Team(name: "Test Team")
    team.scores[round1.id] = 10.0
    team.scores[round2.id] = 15.5
    
    let total = team.totalScore(rounds: rounds)
    XCTAssertEqual(total, 25.5)
}

func testTotalScoreIgnoresOrphanScores() {
    let round1 = Round(name: "R1", format: .standard, questions: [])
    let rounds = [round1]
    
    var team = Team(name: "Test Team")
    team.scores[round1.id] = 10.0
    team.scores[UUID()] = 100.0  // Orphan score
    
    let total = team.totalScore(rounds: rounds)
    XCTAssertEqual(total, 10.0)
}

func testTotalScoreIsZeroForNewTeam() {
    let round1 = Round(name: "R1", format: .standard, questions: [])
    let rounds = [round1]
    
    let team = Team(name: "New Team")
    
    let total = team.totalScore(rounds: rounds)
    XCTAssertEqual(total, 0.0)
}

func testTotalScoreHandlesEmptyRounds() {
    var team = Team(name: "Test Team")
    team.scores[UUID()] = 10.0

    let total = team.totalScore(rounds: [])
    XCTAssertEqual(total, 0.0)
}
}

// MARK: - Tiebreaker Tests

final class TiebreakerTests: XCTestCase {

func testTiebreakerDistanceCalculation() {
    var team = Team(name: "Test Team")
    team.tiebreakerAnswer = 100.0

    // Distance from 100 to 120 is 20
    XCTAssertEqual(team.tiebreakerDistance(from: 120.0), 20.0)

    // Distance from 100 to 80 is also 20 (absolute value)
    XCTAssertEqual(team.tiebreakerDistance(from: 80.0), 20.0)

    // Exact match has distance 0
    XCTAssertEqual(team.tiebreakerDistance(from: 100.0), 0.0)
}

func testTiebreakerDistanceReturnsNilWithoutAnswer() {
    let team = Team(name: "Test Team")
    // No tiebreakerAnswer set

    XCTAssertNil(team.tiebreakerDistance(from: 100.0))
}

func testCompareTiebreakerCloserAnswerWins() {
    var team1 = Team(name: "Team 1")
    team1.tiebreakerAnswer = 95.0  // Distance from 100: 5

    var team2 = Team(name: "Team 2")
    team2.tiebreakerAnswer = 110.0  // Distance from 100: 10

    let correctAnswer = 100.0

    // Team 1 is closer, should win
    XCTAssertTrue(compareTiebreaker(team1, team2, correctAnswer: correctAnswer))
    XCTAssertFalse(compareTiebreaker(team2, team1, correctAnswer: correctAnswer))
}

func testCompareTiebreakerTeamWithAnswerBeatsTeamWithout() {
    var team1 = Team(name: "Team 1")
    team1.tiebreakerAnswer = 500.0  // Has an answer

    let team2 = Team(name: "Team 2")
    // No tiebreakerAnswer

    let correctAnswer = 100.0

    // Team with answer beats team without, regardless of distance
    XCTAssertTrue(compareTiebreaker(team1, team2, correctAnswer: correctAnswer))
    XCTAssertFalse(compareTiebreaker(team2, team1, correctAnswer: correctAnswer))
}

func testCompareTiebreakerFallsBackToLegacyScore() {
    var team1 = Team(name: "Team 1")
    team1.tiebreakerScore = 50.0  // Legacy score

    var team2 = Team(name: "Team 2")
    team2.tiebreakerScore = 30.0  // Legacy score

    // Neither has tiebreakerAnswer, no correct answer available
    XCTAssertTrue(compareTiebreaker(team1, team2, correctAnswer: nil))
    XCTAssertFalse(compareTiebreaker(team2, team1, correctAnswer: nil))
}

func testExtractTiebreakerAnswerFromGameData() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "How many fans?",
        answer: "775,000",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 775000.0)
}

func testExtractTiebreakerAnswerReturnsNilForNonNumeric() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "What is the answer?",
        answer: "Not a number",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertNil(extracted)
}

func testExtractTiebreakerAnswerReturnsNilWithoutTiebreakerQuestion() {
    let regularQuestion = Question(
        format: .standard,
        text: "Regular question?",
        answer: "Answer",
        points: 1.0
    )
    let round = Round(name: "Round 1", format: .standard, questions: [regularQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertNil(extracted)
}

func testExtractTiebreakerAnswerSupportsBillionNotation() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "Population of Earth?",
        answer: "8.1B",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 8_100_000_000.0)
}

func testExtractTiebreakerAnswerSupportsTrillionNotation() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "US National Debt?",
        answer: "34.5T",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 34_500_000_000_000.0)
}

func testExtractTiebreakerAnswerSupportsLowercaseBillionNotation() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "How many?",
        answer: "12.6b",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 12_600_000_000.0)
}

func testExtractTiebreakerAnswerSupportsIntegerBillionNotation() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "How many?",
        answer: "5B",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 5_000_000_000.0)
}

func testExtractTiebreakerAnswerSupportsBillionWithCommas() {
    let tiebreakerQuestion = Question(
        format: .tiebreaker,
        text: "How many?",
        answer: "1,234.5B",
        points: 0
    )
    let round = Round(name: "Final", format: .standard, questions: [tiebreakerQuestion])
    let gameData = TriviaGameData(rounds: [round], teams: [])

    let extracted = extractTiebreakerAnswer(from: gameData)
    XCTAssertEqual(extracted, 1_234_500_000_000.0)
}
}

// MARK: - Validation Rules Tests

final class ValidationRulesTests: XCTestCase {

func testMaxLengthTruncates() {
    let result = ValidationRule.maxLength(5).apply(to: "HelloWorld")
    XCTAssertEqual(result, "Hello")
}

func testNoLeadingWhitespaceRemoves() {
    let result = ValidationRule.noLeadingWhitespace.apply(to: "  Hello")
    XCTAssertEqual(result, "Hello")
}

func testNoWhitespaceRemovesAll() {
    let result = ValidationRule.noWhitespace.apply(to: "Hello World")
    XCTAssertEqual(result, "HelloWorld")
}

func testAlphanumericOnlyFilters() {
    let result = ValidationRule.alphanumericOnly.apply(to: "Hello, World! 123")
    XCTAssertEqual(result, "HelloWorld123")
}

func testNumericOnlyFilters() {
    let result = ValidationRule.numericOnly.apply(to: "abc123def456")
    XCTAssertEqual(result, "123456")
}

func testCustomRuleApplies() {
    let result = ValidationRule.custom { $0.uppercased() }.apply(to: "hello")
    XCTAssertEqual(result, "HELLO")
}

func testMultipleRulesApplyInOrder() {
    let rules: [ValidationRule] = [
        .noLeadingWhitespace,
        .maxLength(10),
        .custom { $0.uppercased() }
    ]
    
    var result = "  Hello World Testing"
    for rule in rules {
        result = rule.apply(to: result)
    }
    
    XCTAssertEqual(result, "HELLO WORL")
}
}

// MARK: - Shared Parsing Helpers Tests

final class ParsingHelpersTests: XCTestCase {

func testCanonicalSpotifyURIConvertsWebURL() {
    let input = "https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh?si=abc123"
    let parsed = TriviaValidator.canonicalSpotifyURI(from: input)
    XCTAssertEqual(parsed, "spotify:track:4iV5W9uYEdYUVa79Axb7Rh")
}

func testCanonicalSpotifyURIRejectsInvalidID() {
    let parsed = TriviaValidator.canonicalSpotifyURI(from: "spotify:track:not-valid!")
    XCTAssertNil(parsed)
}

func testParseTimeToSecondsParsesMMSS() {
    XCTAssertEqual(TriviaValidator.parseTimeToSeconds("1:30"), 90)
}

func testParseTimeToSecondsRejectsInvalidMMSS() {
    XCTAssertNil(TriviaValidator.parseTimeToSeconds("1:80"))
}
}

// MARK: - Comprehensive Validation Tests

final class ComprehensiveValidationTests: XCTestCase {

func testValidGameDataReturnsNoErrors() {
    let gameData = TriviaGameData(
        rounds: [
            Round(name: "General Knowledge", format: .standard, questions: [
                Question(format: .standard, text: "Capital of France?", answer: "Paris", points: 1.0)
            ])
        ],
        teams: [
            Team(name: "Quiz Masters"),
            Team(name: "Brain Trust")
        ]
    )
    
    let errors = TriviaValidator.validateGameData(gameData)
    XCTAssertTrue(errors.isEmpty)
}

func testInvalidGameDataReturnsMultipleErrors() {
    let gameData = TriviaGameData(
        rounds: [
            Round(name: "", format: .standard, questions: []),
            Round(name: "Crossword", format: .crossword, questions: [
                Question(format: .crosswordClue, text: "Clue", answer: "INVALID ANSWER", points: 15.0)
            ])
        ],
        teams: [
            Team(name: "Team A"),
            Team(name: "team a")
        ]
    )
    
    let errors = TriviaValidator.validateGameData(gameData)
    XCTAssertGreaterThanOrEqual(errors.count, 4)
}
}
