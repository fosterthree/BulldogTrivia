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
    let id = UUID()
    let type: SlideType

    /// Display title for sidebar
    var title: String

    /// SF Symbol icon for sidebar
    var icon: String

    /// Associated game data IDs if applicable
    var roundID: UUID?
    var questionID: UUID?

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
        lhs.id == rhs.id &&
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

extension SlideType {
    /// User-friendly description for sidebar
    func displayTitle(rounds: [Round]) -> String {
        switch self {
        case .welcome:
            return "Welcome"
        case .rules:
            return "Rules"
        case .roundTitle(let index):
            guard index < rounds.count else { return "Round \(index + 1)" }
            return rounds[index].name
        case .question(_, let qIndex):
            return "Question \(qIndex + 1)"
        case .submitAnswers:
            return "Submit Answers"
        case .answer(_, let qIndex):
            return "Answer \(qIndex + 1)"
        case .standings(let afterRound):
            if let round = afterRound {
                return "Standings (After Round \(round + 1))"
            } else {
                return "Final Standings"
            }
        case .finalResults:
            return "Final Results"
        case .thankYou:
            return "Thank You"
        }
    }
    
    /// SF Symbol icon for sidebar
    var icon: String {
        switch self {
        case .welcome:
            return "hand.wave.fill"
        case .rules:
            return "list.bullet.clipboard"
        case .roundTitle:
            return "trophy.fill"
        case .question:
            return "questionmark.circle.fill"
        case .submitAnswers:
            return "paperplane.fill"
        case .answer:
            return "checkmark.circle.fill"
        case .standings:
            return "chart.bar.fill"
        case .finalResults:
            return "star.fill"
        case .thankYou:
            return "heart.fill"
        }
    }
}
