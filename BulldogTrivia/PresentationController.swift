//  PresentationController.swift
//  BulldogTrivia

//  Manages presentation state and slide generation.
//  Acts as the source of truth for what's displayed in the presentation window.

//  Created by Asa Foster // 2026

import SwiftUI
import Combine
import OSLog

/// Controls the presentation state and slide navigation for trivia games.
@MainActor
class PresentationController: ObservableObject {

// MARK: - State Structure

/// Encapsulates all presentation-related state for cleaner state management.
///
/// Grouping state reduces the number of change notifications and makes it easier
/// to snapshot state for features like undo/redo or state preservation.
struct PresentationState: Equatable {
    var slides: [PresentationSlide] = []
    var currentSlideIndex: Int = 0
    var standingsRevealCount: Int = 0
    var answerRevealShown: Bool = false
}

// MARK: - Published Properties

@Published var presentationState: PresentationState = PresentationState()
@Published var gameData: TriviaGameData = TriviaGameData()

// MARK: - Private Properties

private let logger = AppLogger.presentation
private var slideIndexByID: [UUID: Int] = [:]
private var questionSlideIndexByQuestionID: [UUID: Int] = [:]

/// Cached tiebreaker answer (invalidated when gameData changes)
private var cachedTiebreakerAnswer: Double?

// MARK: - Convenience Accessors

/// Convenience accessor for slides from presentation state.
var slides: [PresentationSlide] {
    get { presentationState.slides }
    set { presentationState.slides = newValue }
}

/// Convenience accessor for current slide index.
var currentSlideIndex: Int {
    get { presentationState.currentSlideIndex }
    set { presentationState.currentSlideIndex = newValue }
}

/// Convenience accessor for standings reveal count.
var standingsRevealCount: Int {
    get { presentationState.standingsRevealCount }
    set { presentationState.standingsRevealCount = newValue }
}

/// Convenience accessor for answer reveal state.
var answerRevealShown: Bool {
    get { presentationState.answerRevealShown }
    set { presentationState.answerRevealShown = newValue }
}

// MARK: - Computed Properties

var currentSlide: PresentationSlide? {
    guard currentSlideIndex >= 0 && currentSlideIndex < slides.count else {
        return nil
    }
    return slides[currentSlideIndex]
}

var canGoNext: Bool {
    if currentSlideIndex < slides.count - 1 {
        return true
    }
    if let slide = currentSlide, case .standings = slide.type {
        return standingsRevealCount < gameData.teams.count
    }
    return false
}

var canGoPrevious: Bool {
    if currentSlideIndex > 0 {
        return true
    }
    if let slide = currentSlide, case .standings = slide.type {
        return standingsRevealCount > 0
    }
    return false
}

private var currentStandingsTeamCount: Int? {
    guard let slide = currentSlide, case .standings = slide.type else {
        return nil
    }
    return gameData.teams.count
}

// MARK: - Data Management

/// Cached tiebreaker answer accessor
var tiebreakerAnswer: Double? {
    if let cached = cachedTiebreakerAnswer {
        return cached
    }
    let answer = extractTiebreakerAnswer(from: gameData)
    cachedTiebreakerAnswer = answer
    return answer
}

func updateData(_ gameData: TriviaGameData) {
    logger.debug("Updating game data")
    self.gameData = gameData
    cachedTiebreakerAnswer = nil  // Invalidate cache
}

func updateRoundIcon(roundID: UUID, newFormat: RoundFormat) {
    guard let slideIndex = slides.firstIndex(where: { slide in
        if case .roundTitle = slide.type, slide.roundID == roundID {
            return true
        }
        return false
    }) else {
        logger.warning("No round title slide found for round ID: \(roundID)")
        return
    }

    slides[slideIndex].icon = newFormat.symbol
    logger.debug("Updated round icon for round \(roundID) to \(newFormat.symbol)")
}

func generateSlides(from gameData: TriviaGameData) {
    let signpostID = logger.logOperationStart("Generate Slides")
    defer { logger.logOperationEnd("Generate Slides", signpostID: signpostID) }

    self.gameData = gameData
    cachedTiebreakerAnswer = nil  // Invalidate cache

    var newSlides: [PresentationSlide] = []

    // Welcome slide
    newSlides.append(PresentationSlide(
        type: .welcome,
        title: "Welcome",
        icon: "hand.wave.fill"
    ))

    // Pre-compute tiebreaker answer once for all standings slides
    let tiebreakerAnswer = extractTiebreakerAnswer(from: gameData)
    cachedTiebreakerAnswer = tiebreakerAnswer

    // Helper function to parse crossword reveal indices
    func parseRevealIndices(_ indexString: String) -> Set<Int> {
        let components = indexString.split(separator: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        }
        return Set(components)
    }

    // Generate slides for each round
    for (roundIndex, round) in gameData.rounds.enumerated() {
        // Round title
        newSlides.append(PresentationSlide(
            type: .roundTitle(roundIndex: roundIndex),
            title: round.name,
            icon: round.format.symbol,
            roundID: round.id
        ))

        // Questions (skip connections - they're answer-only)
        var questionNumber = 0
        for (qIndex, question) in round.questions.enumerated() {
            if question.format == .connection {
                continue
            }

            questionNumber += 1

            let title: String
            if question.format == .tiebreaker {
                title = "Tiebreaker"
            } else {
                title = "R\(roundIndex + 1) - Q\(questionNumber)"
            }

            // Pre-compute crossword reveal indices if applicable
            let crosswordIndices = question.format == .crosswordClue
                ? parseRevealIndices(question.crosswordRevealIndex ?? "1")
                : nil

            newSlides.append(PresentationSlide(
                type: .question(roundIndex: roundIndex, questionIndex: qIndex),
                title: title,
                icon: "questionmark.circle.fill",
                roundID: round.id,
                questionID: question.id,
                questionNumber: questionNumber,
                crosswordRevealIndices: crosswordIndices
            ))
        }

        // Submit answers
        newSlides.append(PresentationSlide(
            type: .submitAnswers(roundIndex: roundIndex),
            title: "Submit Answers",
            icon: "paperplane.fill",
            roundID: round.id
        ))

        // Answers (including connections)
        questionNumber = 0
        for (qIndex, question) in round.questions.enumerated() {
            let title: String
            if question.format == .tiebreaker {
                title = "Tiebreaker Answer"
            } else if question.format == .connection {
                title = "Connection"
            } else {
                questionNumber += 1
                title = "R\(roundIndex + 1) - A\(questionNumber)"
            }

            // Pre-compute music question flag
            let isMusicQuestion = question.format == .musicQuestion

            // Pre-compute crossword reveal indices if applicable
            let crosswordIndices = question.format == .crosswordClue
                ? parseRevealIndices(question.crosswordRevealIndex ?? "1")
                : nil

            newSlides.append(PresentationSlide(
                type: .answer(roundIndex: roundIndex, questionIndex: qIndex),
                title: title,
                icon: "checkmark.circle.fill",
                roundID: round.id,
                questionID: question.id,
                isMusicQuestion: isMusicQuestion,
                crosswordRevealIndices: crosswordIndices
            ))
        }

        // Standings after this round - pre-compute ranked teams
        let scoringRounds = Array(gameData.rounds.prefix(roundIndex + 1))
        let rankedTeams = gameData.teams
            .withRanks(rounds: scoringRounds, correctTiebreakerAnswer: tiebreakerAnswer)
            .map { (teamID: $0.team.id, teamName: $0.team.name, rank: $0.rank, score: $0.team.totalScore(rounds: scoringRounds)) }

        newSlides.append(PresentationSlide(
            type: .standings(afterRound: roundIndex),
            title: "Standings",
            icon: "chart.bar.fill",
            rankedTeams: rankedTeams
        ))
    }

    self.slides = newSlides
    self.currentSlideIndex = 0
    self.standingsRevealCount = 0
    self.answerRevealShown = false

    // Build lookup dictionaries for O(1) jumps
    // Note: These are rebuilt on every slide generation to ensure consistency.
    // This is acceptable because slide generation is infrequent (only when data changes).
    slideIndexByID = Dictionary(uniqueKeysWithValues:
        newSlides.enumerated().map { ($0.element.id, $0.offset) }
    )
    questionSlideIndexByQuestionID = Dictionary(uniqueKeysWithValues:
        newSlides.enumerated()
            .filter { if case .question = $0.element.type { return true }; return false }
            .compactMap { index, slide in
                slide.questionID.map { ($0, index) }
            }
    )

    logger.info("Generated \(newSlides.count) slides from \(gameData.rounds.count) rounds")
}

// MARK: - Navigation

func next() {
    if let slide = currentSlide, case .answer = slide.type, answerRevealShown == false {
        // Skip sequential reveal for music questions - show answer immediately
        if !slide.isMusicQuestion {
            logger.debug("Revealing answer on current slide")
            withAnimation(.easeOut(duration: PresentationTheme.Animation.revealDuration)) {
                self.answerRevealShown = true
            }
            return
        }
    }

    if let teamCount = currentStandingsTeamCount, standingsRevealCount < teamCount {
        logger.debug("Revealing team \(self.standingsRevealCount + 1) of \(teamCount)")
        withAnimation(.easeOut(duration: PresentationTheme.Animation.revealDuration)) {
            self.standingsRevealCount += 1
        }
        return
    }

    guard currentSlideIndex < slides.count - 1 else {
        logger.debug("Already at last slide")
        return
    }

    self.currentSlideIndex += 1
    self.standingsRevealCount = 0
    self.answerRevealShown = false

    logger.info("Navigated to slide \(self.currentSlideIndex): \(self.slides[self.currentSlideIndex].title)")
}

func previous() {
    if let slide = currentSlide, case .answer = slide.type, answerRevealShown == true {
        // Skip sequential reveal for music questions - show answer immediately
        if !slide.isMusicQuestion {
            logger.debug("Hiding answer on current slide")
            withAnimation(.easeOut(duration: PresentationTheme.Animation.revealDuration)) {
                self.answerRevealShown = false
            }
            return
        }
    }

    if currentStandingsTeamCount != nil, standingsRevealCount > 0 {
        logger.debug("Hiding team \(self.standingsRevealCount)")
        withAnimation(.easeOut(duration: PresentationTheme.Animation.revealDuration)) {
            self.standingsRevealCount -= 1
        }
        return
    }

    guard currentSlideIndex > 0 else {
        logger.debug("Already at first slide")
        return
    }

    self.currentSlideIndex -= 1

    if let slide = currentSlide, case .standings = slide.type {
        self.standingsRevealCount = gameData.teams.count
    }

    if let slide = currentSlide, case .answer = slide.type {
        // For music questions, always show answer; for others, show when navigating back
        self.answerRevealShown = true
    } else {
        self.answerRevealShown = false
    }

    logger.info("Navigated to slide \(self.currentSlideIndex): \(self.slides[self.currentSlideIndex].title)")
}

func jumpTo(index: Int) {
    guard index >= 0 && index < slides.count else {
        logger.warning("Attempted jump to invalid index \(index), valid range: 0-\(self.slides.count - 1)")
        return
    }

    self.currentSlideIndex = index
    self.standingsRevealCount = 0

    // For music questions, show answer immediately; otherwise hide it
    let slide = slides[index]
    if case .answer = slide.type, slide.isMusicQuestion {
        self.answerRevealShown = true
    } else {
        self.answerRevealShown = false
    }

    logger.info("Jumped to slide \(index): \(self.slides[index].title)")
}

func jumpTo(slideID: UUID) {
    guard let index = slideIndexByID[slideID] else {
        logger.warning("Attempted jump to unknown slide ID: \(slideID)")
        return
    }
    jumpTo(index: index)
}

func jumpToQuestion(questionID: UUID) {
    guard let index = questionSlideIndexByQuestionID[questionID] else {
        logger.warning("No question slide found for question ID: \(questionID)")
        return
    }
    jumpTo(index: index)
}

}

