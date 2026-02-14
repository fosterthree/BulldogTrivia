//  TriviaUIExtensions.swift
//  BulldogTrivia

//  Logic and UI Helpers.
//  Separated from Schema to ensure Codable conformance remains non-isolated.

//  Created by Asa Foster // 2026

import SwiftUI
@preconcurrency import AppKit

// MARK: - Logic Helpers
extension Team {
func totalScore(rounds: [Round]) -> Double {
    let validRoundIDs = Set(rounds.map { $0.id })
    return scores.filter { validRoundIDs.contains($0.key) }.values.reduce(0, +)
}

/// Calculates the absolute distance between this team's tiebreaker answer and the correct answer.
///
/// - Parameter correctAnswer: The correct tiebreaker answer.
/// - Returns: The absolute difference, or `nil` if the team hasn't provided an answer.
///
/// Lower values indicate a closer (better) answer.
func tiebreakerDistance(from correctAnswer: Double) -> Double? {
    guard let answer = tiebreakerAnswer else { return nil }
    return abs(answer - correctAnswer)
}
}

// MARK: - Tiebreaker Helpers

/// Extracts the correct tiebreaker answer from game data.
///
/// Searches all rounds for tiebreaker questions and returns the numeric value
/// from the first tiebreaker question's answer field.
///
/// Supports standard notation (e.g., "1000000"), comma-separated notation (e.g., "1,000,000"),
/// billion notation (e.g., "12.6B" = 12,600,000,000), and trillion notation (e.g., "2.3T" = 2,300,000,000,000).
///
/// - Parameter gameData: The game data to search.
/// - Returns: The correct tiebreaker answer as a Double, or nil if not found or not numeric.
func extractTiebreakerAnswer(from gameData: TriviaGameData) -> Double? {
    for round in gameData.rounds {
        for question in round.questions {
            if question.format == .tiebreaker {
                // Parse the answer - remove commas and spaces
                var cleanedAnswer = question.answer
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .uppercased()

                // Check for billion (B) or trillion (T) suffix
                var multiplier: Double = 1.0

                if cleanedAnswer.hasSuffix("T") {
                    multiplier = 1_000_000_000_000 // 1 trillion
                    cleanedAnswer = String(cleanedAnswer.dropLast())
                } else if cleanedAnswer.hasSuffix("B") {
                    multiplier = 1_000_000_000 // 1 billion
                    cleanedAnswer = String(cleanedAnswer.dropLast())
                }

                // Parse the numeric value and apply multiplier
                if let value = Double(cleanedAnswer) {
                    return value * multiplier
                }

                return nil
            }
        }
    }
    return nil
}

/// Compares two teams for tiebreaker ranking.
///
/// Returns true if team1 should rank higher than team2 based on tiebreaker answers.
/// A team with a closer answer to the correct answer ranks higher.
/// Teams without answers rank lower than teams with answers.
///
/// - Parameters:
///   - team1: The first team to compare.
///   - team2: The second team to compare.
///   - correctAnswer: The correct tiebreaker answer.
/// - Returns: True if team1 ranks higher than team2.
func compareTiebreaker(_ team1: Team, _ team2: Team, correctAnswer: Double?) -> Bool {
    guard let correctAnswer = correctAnswer else {
        // No correct answer available, fall back to legacy tiebreakerScore
        return team1.tiebreakerScore > team2.tiebreakerScore
    }

    let distance1 = team1.tiebreakerDistance(from: correctAnswer)
    let distance2 = team2.tiebreakerDistance(from: correctAnswer)

    switch (distance1, distance2) {
    case let (d1?, d2?):
        // Both have answers - closer (lower distance) wins
        if d1 == d2 {
            // If distances are equal, fall back to legacy score
            return team1.tiebreakerScore > team2.tiebreakerScore
        }
        return d1 < d2
    case (_?, nil):
        // Team1 has answer, team2 doesn't - team1 ranks higher
        return true
    case (nil, _?):
        // Team2 has answer, team1 doesn't - team2 ranks higher
        return false
    case (nil, nil):
        // Neither has answer - fall back to legacy tiebreakerScore
        return team1.tiebreakerScore > team2.tiebreakerScore
    }
}

// MARK: - Team Sorting and Ranking

extension Array where Element == Team {
    /// Sorts teams by score and tiebreaker for standings display.
    ///
    /// Teams are sorted in descending order by total score. When scores are equal,
    /// tiebreaker answers are used to determine ranking (closer answer wins).
    ///
    /// - Parameters:
    ///   - rounds: The rounds to calculate scores from.
    ///   - correctTiebreakerAnswer: The correct tiebreaker answer for tie resolution.
    /// - Returns: A sorted array of teams.
    func sortedByStandings(rounds: [Round], correctTiebreakerAnswer: Double?) -> [Team] {
        sorted { t1, t2 in
            let score1 = t1.totalScore(rounds: rounds)
            let score2 = t2.totalScore(rounds: rounds)

            if score1 == score2 {
                return compareTiebreaker(t1, t2, correctAnswer: correctTiebreakerAnswer)
            }
            return score1 > score2
        }
    }

    /// Calculates ranks for all teams, handling ties appropriately.
    ///
    /// Teams with equal scores and equal tiebreaker distances share the same rank.
    ///
    /// - Parameters:
    ///   - rounds: The rounds to calculate scores from.
    ///   - correctTiebreakerAnswer: The correct tiebreaker answer for tie resolution.
    /// - Returns: An array of tuples containing each team and its rank.
    func withRanks(rounds: [Round], correctTiebreakerAnswer: Double?) -> [(team: Team, rank: Int)] {
        let sortedTeams = sortedByStandings(rounds: rounds, correctTiebreakerAnswer: correctTiebreakerAnswer)

        var result: [(Team, Int)] = []
        var currentRank = 1

        for (index, team) in sortedTeams.enumerated() {
            if index > 0 {
                let prevTeam = sortedTeams[index - 1]
                let currentTotal = team.totalScore(rounds: rounds)
                let prevTotal = prevTeam.totalScore(rounds: rounds)

                // Check if tied (same score and same tiebreaker distance)
                let sameTiebreaker: Bool
                if let correctAnswer = correctTiebreakerAnswer {
                    let currentDistance = team.tiebreakerDistance(from: correctAnswer)
                    let prevDistance = prevTeam.tiebreakerDistance(from: correctAnswer)
                    sameTiebreaker = currentDistance == prevDistance
                } else {
                    sameTiebreaker = team.tiebreakerScore == prevTeam.tiebreakerScore
                }

                // If not tied, update rank to current position
                if !(currentTotal == prevTotal && sameTiebreaker) {
                    currentRank = index + 1
                }
            }
            result.append((team, currentRank))
        }
        return result
    }
}

// MARK: - UI Helpers

extension RoundFormat {
var symbol: String {
    switch self {
    case .standard: return "bubble.left.and.bubble.right"
    case .crossword: return "square.grid.3x3"
    case .music: return "music.note"
    case .beforeAndAfter: return "arrow.left.arrow.right"
    }
}

var defaultQuestion: Question {
    switch self {
    case .music:
        return Question(
            format: .musicQuestion,
            text: "",
            answer: "",
            points: 1.0,
            title: "",
            artist: ""
        )
    case .crossword:
        return Question(format: .crosswordClue, text: "", answer: "", points: 1.0)
    case .standard:
        return Question(format: .standard, text: "", answer: "", points: 1.0)
    case .beforeAndAfter:
        return Question(format: .beforeAndAfter, text: "", answer: "", points: 1.0)
    }
}
}

extension Round {
mutating func addDefaultQuestion() {
    questions.append(format.defaultQuestion)
}

mutating func normalizeQuestions(to newFormat: RoundFormat) {
    for i in questions.indices {
        let question = questions[i]
        if question.format == .connection || question.format == .tiebreaker {
            continue
        }

        switch newFormat {
        case .music:
            if questions[i].title.isEmpty && !question.text.isEmpty {
                questions[i].title = question.text
            }
            questions[i].format = .musicQuestion
        case .crossword:
            if questions[i].text.isEmpty && !question.title.isEmpty {
                questions[i].text = question.title
            }
            if questions[i].crosswordRevealIndex == nil {
                questions[i].crosswordRevealIndex = "1"
            }
            questions[i].format = .crosswordClue
        case .standard:
            if questions[i].text.isEmpty && !question.title.isEmpty {
                questions[i].text = question.title
            }
            questions[i].format = .standard
        case .beforeAndAfter:
            if questions[i].text.isEmpty && !question.title.isEmpty {
                questions[i].text = question.title
            }
            questions[i].format = .beforeAndAfter
        }
    }
}
}

extension QuestionFormat {
var leadingSymbol: String {
    switch self {
    case .standard: return ""
    case .connection: return "link.circle.fill"
    case .tiebreaker: return "bolt.circle.fill"
    case .musicQuestion: return "music.note.circle.fill"
    case .crosswordClue: return "square.grid.2x2"
    case .beforeAndAfter: return "arrow.left.arrow.right"
    }
}
}

extension Question {
func sidebarIcon(number: Int) -> String {
    switch format {
    case .standard, .musicQuestion, .crosswordClue, .beforeAndAfter: return "\(number).circle.fill"
    case .connection: return "link.circle.fill"
    case .tiebreaker: return "bolt.circle.fill"
    }
}

var sidebarTitle: String {
    switch format {
    case .connection: return answer.isEmpty ? "Connection..." : answer
    case .tiebreaker: return text.isEmpty ? "Tiebreaker Question..." : text
    case .musicQuestion: return title.isEmpty ? "Music Question..." : title
    case .standard, .crosswordClue: return text.isEmpty ? "Question..." : text
    case .beforeAndAfter: return text.isEmpty ? "Before & After..." : text
    }
}
}

// MARK: - Text Styling

/// A text view with precise line height control using NSTextView
struct StyledText: View {
let text: String
let fontSize: CGFloat
let color: Color
let alignment: NSTextAlignment
let lineHeightMultiple: CGFloat
let fontName: String
let maxWidth: CGFloat

init(
    _ text: String,
    fontSize: CGFloat,
    color: Color = .white,
    alignment: NSTextAlignment = .center,
    lineHeightMultiple: CGFloat = 1.0,
    fontName: String = "Gothic821 Cn BT",
    maxWidth: CGFloat = 1000
) {
    self.text = text
    self.fontSize = fontSize
    self.color = color
    self.alignment = alignment
    self.lineHeightMultiple = lineHeightMultiple
    self.fontName = fontName
    self.maxWidth = maxWidth
}

private var calculatedSize: CGSize {
    let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    paragraphStyle.lineHeightMultiple = lineHeightMultiple
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle
    ]
    
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let boundingRect = attributedString.boundingRect(
        with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    
    return CGSize(width: ceil(boundingRect.width), height: ceil(boundingRect.height))
}

var body: some View {
    StyledTextRepresentable(
        text: text,
        fontSize: fontSize,
        color: NSColor(color),
        alignment: alignment,
        lineHeightMultiple: lineHeightMultiple,
        fontName: fontName
    )
    .frame(width: maxWidth, height: calculatedSize.height)
}
}

private struct StyledTextRepresentable: NSViewRepresentable {
let text: String
let fontSize: CGFloat
let color: NSColor
let alignment: NSTextAlignment
let lineHeightMultiple: CGFloat
let fontName: String

func makeNSView(context: Context) -> NSTextView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = false
    textView.drawsBackground = false
    textView.isRichText = true
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    return textView
}

func updateNSView(_ textView: NSTextView, context: Context) {
    let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    paragraphStyle.lineHeightMultiple = lineHeightMultiple
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]
    
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    textView.textStorage?.setAttributedString(attributedString)
}
}

// MARK: - Window Management

extension View {
    /// Configures the window for presentation mode (16:9 aspect ratio).
    ///
    /// Uses SwiftUI's native GeometryReader to maintain aspect ratio without
    /// complex NSWindow manipulation. The aspect ratio is enforced through layout
    /// rather than window constraints for better SwiftUI integration.
    func configurePresentationWindow() -> some View {
        self
            .background(WindowAspectRatioSetter(aspectRatio: 16.0 / 9.0))
    }
}

// MARK: - Window Aspect Ratio Lock

/// Sets the window's aspect ratio constraint to maintain 16:9
struct WindowAspectRatioSetter: NSViewRepresentable {
    let aspectRatio: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.contentAspectRatio = NSSize(width: aspectRatio, height: 1.0)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.contentAspectRatio = NSSize(width: aspectRatio, height: 1.0)
        }
    }
}
// MARK: - Presentation Key Handling

struct PresentationKeyHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onLeft = onLeft
        view.onRight = onRight
        view.wantsLayer = false
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let catcher = nsView as? KeyCatcherView {
            catcher.onLeft = onLeft
            catcher.onRight = onRight
        }
    }

    final class KeyCatcherView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        private var localMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Tear down any existing monitor when moving between windows
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }

            guard window != nil else { return }

            // Install a local keyDown monitor scoped to this process
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                // Only handle keys when our window is the key window
                guard self.window?.isKeyWindow == true else { return event }
                switch Int(event.keyCode) {
                case 123: // Left arrow
                    self.onLeft?()
                    return nil
                case 124: // Right arrow
                    self.onRight?()
                    return nil
                default:
                    return event
                }
            }
        }

        deinit {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }
}
