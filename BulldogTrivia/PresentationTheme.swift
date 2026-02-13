//  PresentationTheme.swift
//  BulldogTrivia

//  Centralized theme and asset management for presentations.

//  Created by Asa Foster // 2026

import SwiftUI

struct PresentationTheme {
// MARK: - Colors

/// Main brand color - Bulldog Green
static let primaryColor = Color(hex: "487157")

/// White text for high contrast on dark backgrounds
static let textColor = Color.white

/// Secondary text with reduced opacity
static let secondaryTextColor = Color.white.opacity(0.8)

/// Accent colors for specific elements
static let accentYellow = Color.yellow
static let accentCyan = Color.cyan
static let accentGreen = Color.green
static let accentPink = Color.pink

// MARK: - Fonts

/// Custom font name
private static let fontName = "Gothic821 Cn BT"

/// Title font (large headings)
static func titleFont(size: CGFloat = 72) -> Font {
    return Font.custom(fontName, size: size).weight(.bold)
}

/// Subtitle font (medium headings)
static func subtitleFont(size: CGFloat = 56) -> Font {
    return Font.custom(fontName, size: size).weight(.semibold)
}

/// Body font (regular text)
static func bodyFont(size: CGFloat = 48) -> Font {
    return Font.custom(fontName, size: size)
}

/// Caption font (small text)
static func captionFont(size: CGFloat = 36) -> Font {
    return Font.custom(fontName, size: size)
}

// MARK: - Images

/// Main brick background for all slides
static let backgroundImage = "BrickBackground"

// MARK: - Layout Constants

/// Standard horizontal padding for slide content
static let horizontalPadding: CGFloat = 100

/// Standard vertical padding for slide content
static let verticalPadding: CGFloat = 80

/// Standard spacing between elements
static let standardSpacing: CGFloat = 40

// MARK: - Layout Ratios

/// Whiteboard height relative to window
static let whiteboardHeightRatio: CGFloat = 0.99

/// Content width relative to window
static let contentWidthRatio: CGFloat = 0.65

/// Neon sign content width ratio
static let neonContentWidthRatio: CGFloat = 0.7

// MARK: - Font Sizes (at 1x scale)

enum FontSize {
    static let roundNumber: CGFloat = 200
    static let roundName: CGFloat = 120
    static let questionText: CGFloat = 90
    static let questionNumber: CGFloat = 200
    static let answerText: CGFloat = 150
    static let answerQuestion: CGFloat = 80
    static let musicTitle: CGFloat = 150
    static let musicArtist: CGFloat = 75
    static let submitText: CGFloat = 160
    static let tiebreakerLabel: CGFloat = 70
    static let crosswordLetter: CGFloat = 120
    static let crosswordClue: CGFloat = 90
}

// MARK: - Crossword Layout

enum Crossword {
    static let letterBoxSize: CGFloat = 140
    static let letterBoxHeight: CGFloat = 180
    static let letterSpacing: CGFloat = 12
    static let borderWidth: CGFloat = 10
    /// Maximum letters in a crossword answer - references schema constant for single source of truth.
    static let maxLetters: Int = TriviaSchemaConstants.crosswordMaxLetters
}

// MARK: - Standings Layout

enum Standings {
    static let cardHeight: CGFloat = 93
    static let cardSpacing: CGFloat = -10
    static let topPadding: CGFloat = 70
    static let bottomPadding: CGFloat = 55
    static let maxVisibleTeams: Int = 11
    static let rankSquareSize: CGFloat = 45
    static let rankFontSize: CGFloat = 38
    static let maxRandomXOffset: CGFloat = 20
    static let baseXOffset: CGFloat = 5
    static let maxRotation: Double = 1.5
    static let baseRotation: Double = 0.5
    static let shadowOpacityMultiplier: Double = 0.025
}

// MARK: - Separator Layout

enum Separator {
    static let width: CGFloat = 800
    static let height: CGFloat = 20
    static let opacity: Double = 0.3
    static let bottomPadding: CGFloat = 20
}

// MARK: - Animation

enum Animation {
    static let standardDuration: Double = 0.3
    static let revealDuration: Double = 0.3
}
}

// MARK: - Color Extension for Hex Support

extension Color {
init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
        (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
        (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
        (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
        (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: Double(a) / 255
    )
}
}

// MARK: - Themed Background Modifier

struct ThemedSlideBackground: ViewModifier {
func body(content: Content) -> some View {
    ZStack {
        // Background image
        Image(PresentationTheme.backgroundImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()

        // Content
        content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
}

extension View {
func themedSlideBackground() -> some View {
    self.modifier(ThemedSlideBackground())
}
}
