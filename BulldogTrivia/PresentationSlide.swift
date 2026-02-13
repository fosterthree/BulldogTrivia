//  PresentationSlide.swift
//  BulldogTrivia

//  Defines the slide model and types for the presentation.

//  Created by Asa Foster // 2026

import Foundation

/// Represents the different types of slides in a presentation
enum SlideType: Hashable, Codable {
    case welcome
    case roundTitle(roundIndex: Int)
    case question(roundIndex: Int, questionIndex: Int)
    case submitAnswers(roundIndex: Int)
    case answer(roundIndex: Int, questionIndex: Int)
    case standings(afterRound: Int?)  // nil = final standings

    // MARK: Reserved for Future Use
    // These cases are not currently generated but are kept for potential future features
    case rules
    case finalResults
    case thankYou
}

/// A single slide in the presentation
struct PresentationSlide: Identifiable {
    let type: SlideType

    /// Display title for sidebar
    var title: String

    /// SF Symbol icon for sidebar
    var icon: String

    /// Associated game data IDs if applicable
    var roundID: UUID?
    var questionID: UUID?

    /// Stable, deterministic ID based on slide content
    /// This prevents unnecessary view recreation when slides regenerate
    var id: String {
        switch type {
        case .welcome:
            return "welcome"
        case .rules:
            return "rules"
        case .roundTitle(let roundIndex):
            if let roundID = roundID {
                return "round-\(roundID.uuidString)"
            }
            return "round-\(roundIndex)"
        case .question(let roundIndex, let questionIndex):
            if let questionID = questionID {
                return "question-\(questionID.uuidString)"
            }
            return "question-\(roundIndex)-\(questionIndex)"
        case .submitAnswers(let roundIndex):
            if let roundID = roundID {
                return "submit-\(roundID.uuidString)"
            }
            return "submit-\(roundIndex)"
        case .answer(let roundIndex, let questionIndex):
            if let questionID = questionID {
                return "answer-\(questionID.uuidString)"
            }
            return "answer-\(roundIndex)-\(questionIndex)"
        case .standings(let afterRound):
            if let afterRound = afterRound {
                return "standings-\(afterRound)"
            }
            return "standings-final"
        case .finalResults:
            return "final-results"
        case .thankYou:
            return "thank-you"
        }
    }

    // MARK: - Performance Optimization: Pre-computed Values

    /// Pre-computed question number (1-based, excluding connections)
    /// Avoids O(n) filtering on every render
    var questionNumber: Int?

    /// Pre-computed flag for music questions
    /// Avoids repeated bounds checking and lookups
    var isMusicQuestion: Bool = false

    /// Pre-computed crossword reveal indices (1-based)
    /// Avoids string parsing on every render
    var crosswordRevealIndices: Set<Int>?

    /// Pre-computed ranked teams for standings slides
    /// Avoids O(t log t) sorting on every render
    var rankedTeams: [(teamID: UUID, teamName: String, rank: Int, score: Double)]?
}

// MARK: - Equatable & Hashable Conformance

extension PresentationSlide: Equatable {
    static func == (lhs: PresentationSlide, rhs: PresentationSlide) -> Bool {
        // Compare all properties except rankedTeams (which can't be directly compared)
        lhs.type == rhs.type &&
        lhs.title == rhs.title &&
        lhs.icon == rhs.icon &&
        lhs.roundID == rhs.roundID &&
        lhs.questionID == rhs.questionID &&
        lhs.questionNumber == rhs.questionNumber &&
        lhs.isMusicQuestion == rhs.isMusicQuestion &&
        lhs.crosswordRevealIndices == rhs.crosswordRevealIndices &&
        areRankedTeamsEqual(lhs.rankedTeams, rhs.rankedTeams)
    }

    private static func areRankedTeamsEqual(
        _ lhs: [(teamID: UUID, teamName: String, rank: Int, score: Double)]?,
        _ rhs: [(teamID: UUID, teamName: String, rank: Int, score: Double)]?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (let lhsTeams?, let rhsTeams?):
            guard lhsTeams.count == rhsTeams.count else { return false }
            return zip(lhsTeams, rhsTeams).allSatisfy { lTeam, rTeam in
                lTeam.teamID == rTeam.teamID &&
                lTeam.teamName == rTeam.teamName &&
                lTeam.rank == rTeam.rank &&
                lTeam.score == rTeam.score
            }
        default:
            return false
        }
    }
}

extension PresentationSlide: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(title)
        hasher.combine(icon)
        hasher.combine(roundID)
        hasher.combine(questionID)
        hasher.combine(questionNumber)
        hasher.combine(isMusicQuestion)
        hasher.combine(crosswordRevealIndices)
        // Hash rankedTeams by hashing individual team IDs and ranks
        if let teams = rankedTeams {
            hasher.combine(teams.count)
            for team in teams {
                hasher.combine(team.teamID)
                hasher.combine(team.rank)
            }
        }
    }
}
