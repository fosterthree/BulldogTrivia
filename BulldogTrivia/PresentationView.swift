//  PresentationView.swift
//  BulldogTrivia

//  The main presentation window view.

//  Created by Asa Foster // 2026

import SwiftUI

struct PresentationView: View {
@EnvironmentObject var presentationController: PresentationController

var body: some View {
    GeometryReader { geometry in
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Slide Content with scaling
            if let slide = presentationController.currentSlide {
                slideView(for: slide, geometry: geometry)
            } else {
                // No slide selected
                VStack(spacing: 20) {
                    Image(systemName: "tv")
                        .font(.system(size: 120 * scaleFactor(for: geometry)))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Waiting for Presentation...")
                        .font(.system(size: 48 * scaleFactor(for: geometry)))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Waiting for presentation to start")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Calculate scale factor based on window size (reference: 1920x1080)
private func scaleFactor(for geometry: GeometryProxy) -> CGFloat {
    let referenceWidth: CGFloat = 1920
    let referenceHeight: CGFloat = 1080
    
    let widthScale = geometry.size.width / referenceWidth
    let heightScale = geometry.size.height / referenceHeight
    
    // Use the smaller scale to ensure content fits
    return min(widthScale, heightScale)
}

@ViewBuilder
private func slideView(for slide: PresentationSlide, geometry: GeometryProxy) -> some View {
    let gameData = presentationController.gameData
    let scale = scaleFactor(for: geometry)
    
    switch slide.type {
    case .welcome:
        WelcomeSlide(scale: scale)
    case .roundTitle(let roundIndex):
        if roundIndex < gameData.rounds.count {
            RoundTitleSlide(
                round: gameData.rounds[roundIndex],
                roundIndex: roundIndex,
                scale: scale,
                windowHeight: geometry.size.height,
                windowWidth: geometry.size.width
            )
        }
    case .question(let roundIndex, let qIndex):
        if roundIndex < gameData.rounds.count,
           qIndex < gameData.rounds[roundIndex].questions.count {
            QuestionSlide(
                question: gameData.rounds[roundIndex].questions[qIndex],
                questionNumber: slide.questionNumber ?? 1,
                scale: scale,
                windowHeight: geometry.size.height,
                windowWidth: geometry.size.width,
                crosswordRevealIndices: slide.crosswordRevealIndices
            )
        }
    case .submitAnswers:
        SubmitAnswersSlide(
            scale: scale,
            windowHeight: geometry.size.height,
            windowWidth: geometry.size.width
        )
    case .answer(let roundIndex, let qIndex):
        if roundIndex < gameData.rounds.count,
           qIndex < gameData.rounds[roundIndex].questions.count {
            AnswerSlide(
                question: gameData.rounds[roundIndex].questions[qIndex],
                scale: scale,
                windowHeight: geometry.size.height,
                windowWidth: geometry.size.width,
                crosswordRevealIndices: slide.crosswordRevealIndices
            )
        }
    case .standings:
        StandingsSlide(
            rankedTeams: slide.rankedTeams ?? [],
            scale: scale,
            windowHeight: geometry.size.height,
            revealCount: presentationController.standingsRevealCount
        )
    }
}
}

// MARK: - Helper Functions

/// Calculates the scale factor for crossword letter boxes based on answer length.
///
/// Scales down boxes proportionally when answers exceed 9 letters to ensure they fit on screen
/// while maintaining readability.
///
/// - Parameter answer: The crossword answer string to calculate scaling for.
/// - Returns: A scale factor between 0 and 1.0 (1.0 = no scaling).
private func crosswordScaleFactor(for answer: String) -> CGFloat {
    let truncatedAnswer = String(answer.uppercased().prefix(PresentationTheme.Crossword.maxLetters))
    let letterCount = truncatedAnswer.count
    return letterCount > 9 ? min(1.0, 9.0 / CGFloat(letterCount)) : 1.0
}

// MARK: - Individual Slide Views

struct WelcomeSlide: View {
let scale: CGFloat

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Image("NeonBrick")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Welcome to Bulldog Trivia")
        .accessibilityAddTraits(.isImage)
    }
}
}

struct RoundTitleSlide: View {
let round: Round
let roundIndex: Int
let scale: CGFloat
let windowHeight: CGFloat
let windowWidth: CGFloat

private var contentWidth: CGFloat {
    windowWidth * PresentationTheme.contentWidthRatio
}

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Color.clear
                .themedSlideBackground()

            Image("Whiteboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: windowHeight * PresentationTheme.whiteboardHeightRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

            VStack(spacing: 10) {
                Text("ROUND \(roundIndex + 1)")
                    .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.roundNumber * scale))
                    .foregroundStyle(PresentationTheme.primaryColor)

                Image("LumpySeparator")
                    .resizable()
                    .frame(
                        width: PresentationTheme.Separator.width * scale,
                        height: PresentationTheme.Separator.height * scale
                    )
                    .opacity(PresentationTheme.Separator.opacity)
                    .padding(.bottom, PresentationTheme.Separator.bottomPadding * scale)

                Text(round.name.uppercased())
                    .frame(width: contentWidth)
                    .multilineTextAlignment(.center)
                    .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.roundName * scale))
                    .foregroundStyle(PresentationTheme.primaryColor)
            }
            .offset(y: -50 * scale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Round \(roundIndex + 1): \(round.name)")
    }
}
}

struct QuestionSlide: View {
let question: Question
let questionNumber: Int
let scale: CGFloat
let windowHeight: CGFloat
let windowWidth: CGFloat
let crosswordRevealIndices: Set<Int>?

private var contentWidth: CGFloat {
    windowWidth * PresentationTheme.contentWidthRatio
}

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Color.clear
                .themedSlideBackground()

            Image("Whiteboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: windowHeight * PresentationTheme.whiteboardHeightRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

            VStack {
                if question.format == .tiebreaker {
                    Text("TIEBREAKER:")
                        .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.tiebreakerLabel * scale))
                        .foregroundStyle(PresentationTheme.primaryColor.opacity(0.7))
                        .padding(.bottom, 20 * scale)
                }

                if question.format == .musicQuestion {
                    Text("SONG \(questionNumber)")
                        .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.questionNumber * scale))
                        .foregroundStyle(PresentationTheme.primaryColor)
                } else if question.format == .crosswordClue {
                    crosswordQuestionContent
                } else if question.format == .beforeAndAfter {
                    beforeAndAfterQuestionContent
                } else {
                    Text(question.text.uppercased())
                        .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.questionText * scale))
                        .foregroundStyle(PresentationTheme.primaryColor)
                }
            }
            .frame(width: contentWidth)
            .foregroundStyle(PresentationTheme.primaryColor)
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}

private var crosswordQuestionContent: some View {
    let scaleFactor = crosswordScaleFactor(for: question.answer)
    let revealIndices = crosswordRevealIndices ?? Set([1])

    return VStack(spacing: 100 * scale) {
        Text(question.text.uppercased())
            .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.crosswordClue * scale))
            .foregroundStyle(PresentationTheme.primaryColor)
            .padding(.horizontal, PresentationTheme.horizontalPadding * scale)

        HStack(spacing: PresentationTheme.Crossword.letterSpacing * scale * scaleFactor) {
            let answer = String(question.answer.uppercased().prefix(PresentationTheme.Crossword.maxLetters))
            ForEach(0..<answer.count, id: \.self) { index in
                let char = Array(answer)[index]
                // 1-based index check
                let shouldReveal = revealIndices.contains(index + 1)

                Text(shouldReveal ? String(char) : " ")
                    .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.crosswordLetter * scale * scaleFactor))
                    .foregroundStyle(PresentationTheme.primaryColor)
                    .frame(
                        width: PresentationTheme.Crossword.letterBoxSize * scale * scaleFactor,
                        height: PresentationTheme.Crossword.letterBoxHeight * scale * scaleFactor
                    )
                    .border(PresentationTheme.primaryColor, width: PresentationTheme.Crossword.borderWidth * scale)
                    .zIndex(shouldReveal ? 1 : 0)
            }
        }
    }
}

private var beforeAndAfterQuestionContent: some View {
    VStack(spacing: 50 * scale) {
        Text(question.text.uppercased())
            .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.questionText * scale))
            .foregroundStyle(PresentationTheme.primaryColor)

        Text("&")
            .font(PresentationTheme.titleFont(size: 100 * scale))
            .foregroundStyle(PresentationTheme.primaryColor)

        Text(question.artist.uppercased())
            .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.questionText * scale))
            .foregroundStyle(PresentationTheme.primaryColor)
    }
}

private var accessibilityDescription: String {
    switch question.format {
    case .tiebreaker:
        return "Tiebreaker question: \(question.text)"
    case .musicQuestion:
        return "Song number \(questionNumber)"
    case .crosswordClue:
        return "Crossword clue: \(question.text). \(question.answer.count) letters."
    case .beforeAndAfter:
        return "Before and After: \(question.text) and \(question.artist)"
    default:
        return "Question \(questionNumber): \(question.text)"
    }
}
}

struct AnswerSlide: View {
@EnvironmentObject var presentationController: PresentationController

let question: Question
let scale: CGFloat
let windowHeight: CGFloat
let windowWidth: CGFloat
let crosswordRevealIndices: Set<Int>?

private var contentWidth: CGFloat {
    windowWidth * PresentationTheme.contentWidthRatio
}

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Color.clear
                .themedSlideBackground()
            
            Image("Whiteboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: windowHeight * PresentationTheme.whiteboardHeightRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            VStack(spacing: 50 * scale) {
                if question.format == .connection {
                    Text("CONNECTION:")
                        .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.tiebreakerLabel * scale))
                        .opacity(0.7)
                } else if question.format == .tiebreaker {
                    Text("TIEBREAKER:")
                        .font(PresentationTheme.subtitleFont(size: PresentationTheme.FontSize.tiebreakerLabel * scale))
                        .opacity(0.7)
                } else if question.format == .musicQuestion {
                    StyledText(
                        question.title.uppercased(),
                        fontSize: 120 * scale,
                        color: PresentationTheme.primaryColor,
                        alignment: .center,
                        lineHeightMultiple: 0.8,
                        maxWidth: contentWidth
                    )
                    Text("\(question.artist.uppercased())")
                        .font(PresentationTheme.bodyFont(size: PresentationTheme.FontSize.musicArtist * scale))
                } else if question.format == .crosswordClue {
                    crosswordAnswerContent
                } else if question.format == .beforeAndAfter {
                    beforeAndAfterAnswerContent
                } else if question.format != .connection {
                    Text(question.text.uppercased())
                        .font(PresentationTheme.bodyFont(size: PresentationTheme.FontSize.answerQuestion * scale))
                        .opacity(0.7)
                }
                
                if question.format != .crosswordClue && question.format != .beforeAndAfter {
                    if presentationController.answerRevealShown {
                        StyledText(
                            question.answer.uppercased(),
                            fontSize: PresentationTheme.FontSize.answerText * scale,
                            color: PresentationTheme.primaryColor,
                            alignment: .center,
                            lineHeightMultiple: 0.8,
                            maxWidth: contentWidth
                        )
                    }
                }
            }
            .frame(width: contentWidth)
            .foregroundStyle(PresentationTheme.primaryColor)
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}

private var crosswordAnswerContent: some View {
    let scaleFactor = crosswordScaleFactor(for: question.answer)

    return VStack(spacing: 100 * scale) {
        Text(question.text.uppercased())
            .font(PresentationTheme.bodyFont(size: PresentationTheme.FontSize.answerQuestion * scale))
            .opacity(0.7)

        HStack(spacing: PresentationTheme.Crossword.letterSpacing * scale * scaleFactor) {
            let answer = String(question.answer.uppercased().prefix(PresentationTheme.Crossword.maxLetters))
            if presentationController.answerRevealShown {
                ForEach(Array(answer.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.crosswordLetter * scale * scaleFactor))
                        .frame(
                            width: PresentationTheme.Crossword.letterBoxSize * scale * scaleFactor,
                            height: PresentationTheme.Crossword.letterBoxHeight * scale * scaleFactor
                        )
                        .border(PresentationTheme.primaryColor, width: PresentationTheme.Crossword.borderWidth * scale)
                }
            } else {
                ForEach(Array(answer.enumerated()), id: \.offset) { _ , _ in
                    Text(" ")
                        .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.crosswordLetter * scale * scaleFactor))
                        .frame(
                            width: PresentationTheme.Crossword.letterBoxSize * scale * scaleFactor,
                            height: PresentationTheme.Crossword.letterBoxHeight * scale * scaleFactor
                        )
                        .border(PresentationTheme.primaryColor, width: PresentationTheme.Crossword.borderWidth * scale)
                }
            }
        }
    }
}

private var beforeAndAfterAnswerContent: some View {
    VStack(spacing: 50 * scale) {
        // Show both clues with reduced opacity
        VStack(spacing: 20 * scale) {
            Text(question.text.uppercased())
                .font(PresentationTheme.bodyFont(size: PresentationTheme.FontSize.answerQuestion * scale * 0.8))
                .opacity(0.5)

            Text("&")
                .font(PresentationTheme.titleFont(size: 60 * scale))
                .opacity(0.5)

            Text(question.artist.uppercased())
                .font(PresentationTheme.bodyFont(size: PresentationTheme.FontSize.answerQuestion * scale * 0.8))
                .opacity(0.5)
        }

        // Show answer only when revealed
        if presentationController.answerRevealShown {
            StyledText(
                question.answer.uppercased(),
                fontSize: PresentationTheme.FontSize.answerText * scale,
                color: PresentationTheme.primaryColor,
                alignment: .center,
                lineHeightMultiple: 0.9,
                maxWidth: contentWidth
            )
        }
    }
}

private var accessibilityDescription: String {
    switch question.format {
    case .connection:
        return "Connection answer: \(question.answer)"
    case .tiebreaker:
        return "Tiebreaker answer: \(question.answer)"
    case .musicQuestion:
        return "Song: \(question.title) by \(question.artist)"
    case .crosswordClue:
        return "Crossword answer: \(question.answer)"
    case .beforeAndAfter:
        return "Before and After answer: \(question.answer)"
    default:
        return "Answer: \(question.answer)"
    }
}
}

struct SubmitAnswersSlide: View {
let scale: CGFloat
let windowHeight: CGFloat
let windowWidth: CGFloat

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Color.clear
                .themedSlideBackground()
            
            Image("Whiteboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: windowHeight * PresentationTheme.whiteboardHeightRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            Text("PLEASE SUBMIT YOUR ANSWERS")
                .font(PresentationTheme.titleFont(size: PresentationTheme.FontSize.submitText * scale))
                .foregroundStyle(PresentationTheme.primaryColor)
                .multilineTextAlignment(.center)
                .frame(width: windowWidth * PresentationTheme.neonContentWidthRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Please submit your answers")
    }
}
}

struct StandingsSlide: View {
let rankedTeams: [(teamID: UUID, teamName: String, rank: Int, score: Double)]
let scale: CGFloat
let windowHeight: CGFloat
let revealCount: Int

private let referenceHeight: CGFloat = 1080

private func isTeamVisible(at index: Int) -> Bool {
    let totalTeams = rankedTeams.count
    return index >= totalTeams - revealCount
}

private var scrollOffset: Int {
    let totalTeams = rankedTeams.count
    let maxVisible = PresentationTheme.Standings.maxVisibleTeams
    let firstVisibleIndex = max(0, totalTeams - revealCount)
    return max(0, min(firstVisibleIndex, totalTeams - maxVisible))
}

private func yPosition(for index: Int) -> CGFloat {
    let effectiveSpacing = PresentationTheme.Standings.cardHeight + PresentationTheme.Standings.cardSpacing
    let visualIndex = CGFloat(index - scrollOffset)
    return PresentationTheme.Standings.topPadding + (visualIndex * effectiveSpacing) + (PresentationTheme.Standings.cardHeight / 2)
}

var body: some View {
    GeometryReader { geometry in
        ZStack {
            Color.clear
                .themedSlideBackground()
            
            Image("Corkboard")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: windowHeight * PresentationTheme.whiteboardHeightRatio)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                ForEach(Array(rankedTeams.enumerated()), id: \.element.teamID) { index, item in
                    if isTeamVisible(at: index) {
                        PresentationTeamCard(
                            rank: item.rank,
                            teamName: item.teamName,
                            score: item.score,
                            scale: scale,
                            teamID: item.teamID,
                            cardIndex: index
                        )
                        .frame(height: PresentationTheme.Standings.cardHeight * scale)
                        .position(
                            x: geometry.size.width / 2,
                            y: yPosition(for: index) * scale
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mask {
                Rectangle()
                    .padding(.top, PresentationTheme.Standings.topPadding * scale)
                    .padding(.bottom, (PresentationTheme.Standings.topPadding + PresentationTheme.Standings.bottomPadding) * scale)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(standingsAccessibilityLabel)
    }
}

private var standingsAccessibilityLabel: String {
    let visibleTeams = rankedTeams.enumerated()
        .filter { isTeamVisible(at: $0.offset) }
        .map { "\($0.element.rank). \($0.element.teamName): \($0.element.score.formatted()) points" }

    if visibleTeams.isEmpty {
        return "Standings. No teams revealed yet."
    }
    return "Standings. \(visibleTeams.joined(separator: ". "))"
}
}

struct PresentationTeamCard: View {
let rank: Int
let teamName: String
let score: Double
let scale: CGFloat
let teamID: UUID
let cardIndex: Int

private var formattedScore: String {
    if score.truncatingRemainder(dividingBy: 1) == 0 {
        return String(Int(score))
    } else {
        return String(format: "%.1f", score)
    }
}

private var randomXOffset: CGFloat {
    let hash = abs(teamID.hashValue)
    let normalized = Double(hash % 1000) / 1000.0
    return (normalized * PresentationTheme.Standings.maxRandomXOffset - PresentationTheme.Standings.baseXOffset) * scale
}

private var randomRotation: Double {
    let hash = abs(teamID.hashValue)
    let normalized = Double((hash / 1000) % 1000) / 1000.0
    return normalized * PresentationTheme.Standings.maxRotation - PresentationTheme.Standings.baseRotation
}

private var shadowOpacity: Double {
    return Double(cardIndex) * PresentationTheme.Standings.shadowOpacityMultiplier
}

var body: some View {
    Image("TeamCard")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .overlay(alignment: .center) {
            HStack(spacing: 20 * scale) {
                ZStack {
                    Image("LumpySquare")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: PresentationTheme.Standings.rankSquareSize * scale,
                            height: PresentationTheme.Standings.rankSquareSize * scale
                        )
                    
                    Text("\(rank)")
                        .font(PresentationTheme.bodyFont(size: PresentationTheme.Standings.rankFontSize * scale))
                        .foregroundStyle(.white)
                }
                
                Text(teamName.uppercased())
                    .font(PresentationTheme.bodyFont(size: PresentationTheme.Standings.rankFontSize * scale))
                    .foregroundStyle(PresentationTheme.primaryColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(formattedScore)
                    .font(PresentationTheme.bodyFont(size: PresentationTheme.Standings.rankFontSize * scale))
                    .foregroundStyle(PresentationTheme.primaryColor)
            }
            .padding(.top, 10 * scale)
            .padding(.horizontal, 25 * scale)
        }
        .overlay {
            Image("TeamCardShadow")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(shadowOpacity)
                .allowsHitTesting(false)
        }
        .offset(x: randomXOffset)
        .rotationEffect(.degrees(randomRotation))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(rank): \(teamName), \(formattedScore) points")
}
}

