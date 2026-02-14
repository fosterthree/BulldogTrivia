//  QuestionCard.swift
//  BulldogTrivia

//  The specific view component for a single question.

//  Created by Asa Foster on 1/20/26.

import SwiftUI

struct QuestionCard: View {
let number: Int
@Binding var question: Question
let roundFormat: RoundFormat
let isHighlighted: Bool
let onDelete: () -> Void

@EnvironmentObject var spotifyController: SpotifyController
@EnvironmentObject var presentationController: PresentationController
@FocusState private var focusedField: String?
@State private var localPointsText = ""

private let pointsFieldID = "points"

var body: some View {
    HStack(alignment: .top, spacing: 14) {
        leadingIcon

        Divider()
            .frame(width: 1)
            .padding(.vertical, -8)
            .allowsHitTesting(false)

        if question.format == .musicQuestion {
            musicBody
        } else if question.format == .beforeAndAfter {
            beforeAndAfterBody
        } else {
            standardBody
        }

        if question.format != .tiebreaker {
            Divider()
                .frame(width: 1)
                .padding(.vertical, -8)
                .allowsHitTesting(false)

            pointValueField
                .frame(width: 40)
        }
    }
    .padding(14)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                isHighlighted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator.opacity(0.35)),
                lineWidth: isHighlighted ? 2 : 1
            )
    )
    .contextMenu {
        if roundFormat == .music {
            Section("Question Format") {
                musicRoundFormatMenu
            }
        } else if roundFormat == .standard {
            Section("Question Format") {
                formatMenu
            }
        } else if roundFormat == .beforeAndAfter {
            Section("Question Format") {
                beforeAndAfterRoundFormatMenu
            }
        } else if roundFormat == .crossword {
            Section("Question Format") {
                crosswordRoundFormatMenu
            }
        }

        Divider()

        Toggle(isOn: $question.showPresenterNotes) {
            Text("Presenter Notes")
        }

        Divider()

        Button("Delete", systemImage: "trash", role: .destructive) {
            onDelete()
        }
        .accessibilityLabel("Delete question \(number)")
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Question \(number)")
}

private var leadingIcon: some View {
    VStack {
        Spacer(minLength: 0)
        Image(systemName: question.sidebarIcon(number: number))
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .accessibilityHidden(true)
        Spacer(minLength: 0)
    }
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
        presentationController.jumpToQuestion(questionID: question.id)
    }
}

// MARK: - Point Value Field
private var pointValueField: some View {
    VStack {
        Spacer(minLength: 0)

        VStack(spacing: 4) {
            let isPointsFocused = focusedField == pointsFieldID
            let isValidPoints = pointsFieldValidationValue(isFocused: isPointsFocused)
                .map { TriviaValidator.validatePoints($0) == nil }
                ?? (isPointsFocused && localPointsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            TextField("1", text: $localPointsText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.body)
                .monospacedDigit()
                .padding(10)
                .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            !isValidPoints ? Color.red :
                            (isPointsFocused ? Color.accentColor : Color.secondary.opacity(0.35)),
                            lineWidth: !isValidPoints ? 2 : (isPointsFocused ? 2 : 1)
                        )
                )
                .focused($focusedField, equals: pointsFieldID)
                .onAppear { syncPointsFieldFromModel() }
                .onChange(of: question.points) { _, _ in
                    if focusedField != pointsFieldID {
                        syncPointsFieldFromModel()
                    }
                }
                .onSubmit {
                    commitPointsField()
                }
                .onChange(of: focusedField == pointsFieldID) { _, isFocused in
                    if isFocused {
                        syncPointsFieldFromModel()
                    } else {
                        commitPointsField()
                    }
                }

            Text(question.points == 1 ? "POINT" : "POINTS")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }

        Spacer(minLength: 0)
    }
}

// MARK: - Standard Body
private var standardBody: some View {
    VStack(spacing: 10) {
        if question.format == .connection {
            Spacer(minLength: 0)
        }

        if question.format != .connection {
            labeledTextField(
                title: questionPlaceholder,
                text: $question.text,
                icon: "q.circle",
                isVertical: true,
                accessibilityLabel: "Question text",
                validationRules: ValidationPresets.questionText,
                fieldID: "question"
            )
        }

        HStack(alignment: .center, spacing: 10) {
            let isAnswerInvalid = question.format == .crosswordClue && TriviaValidator.validateCrosswordAnswer(question.answer) != nil

            labeledTextField(
                title: answerPlaceholder,
                text: $question.answer,
                icon: "a.circle",
                accessibilityLabel: answerPlaceholder,
                alwaysItalic: true,
                alwaysSecondary: true,
                hasError: isAnswerInvalid,
                validationRules: question.format == .crosswordClue ? ValidationPresets.crosswordAnswer : ValidationPresets.answerText,
                fieldID: "answer"
            )
            .help(isAnswerInvalid ? "Crossword answers must be 12 characters or less and cannot contain spaces." : "")

            if question.format == .crosswordClue {
                let revealBinding = Binding<String>(
                    get: { question.crosswordRevealIndex ?? "1" },
                    set: { newValue in
                        question.crosswordRevealIndex = newValue
                    }
                )

                LabeledContent {
                    TextField("1,2", text: revealBinding)
                        .textFieldStyle(.plain)
                        .frame(width: 30)
                        .padding(10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    focusedField == "crosswordReveal" ? Color.accentColor : Color.secondary.opacity(0.35),
                                    lineWidth: focusedField == "crosswordReveal" ? 2 : 1
                                )
                        )
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: "crosswordReveal")
                } label: {
                    Image(systemName: "character.cursor.ibeam")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .help("Which letter index/indices to reveal (1-based, comma-separated for multiple)")
            }
        }

        if question.showPresenterNotes {
            labeledTextField(
                title: "Presenter Notes...",
                text: $question.presenterNotes,
                icon: "long.text.page.and.pencil",
                isVertical: true,
                accessibilityLabel: "Presenter notes",
                fieldID: "presenterNotes"
            )
        }

        if question.format == .connection {
            Spacer(minLength: 0)
        }
    }
}

private var questionPlaceholder: String {
    question.format == .tiebreaker ? "Tiebreaker Question..." : "Question..."
}

private var answerPlaceholder: String {
    question.format == .connection ? "Connection..." : "Answer..."
}

// MARK: - Before & After Body
private var beforeAndAfterBody: some View {
    VStack(spacing: 10) {
        labeledTextField(
            title: "Clue 1...",
            text: $question.text,
            icon: "1.circle",
            isVertical: true,
            accessibilityLabel: "First clue",
            validationRules: ValidationPresets.questionText,
            fieldID: "clue1"
        )

        labeledTextField(
            title: "Clue 2...",
            text: $question.artist,
            icon: "2.circle",
            isVertical: true,
            accessibilityLabel: "Second clue",
            validationRules: ValidationPresets.questionText,
            fieldID: "clue2"
        )

        labeledTextField(
            title: "Combined Answer...",
            text: $question.answer,
            icon: "a.circle",
            accessibilityLabel: "Combined answer",
            alwaysItalic: true,
            alwaysSecondary: true,
            validationRules: ValidationPresets.answerText,
            fieldID: "answer"
        )

        if question.showPresenterNotes {
            labeledTextField(
                title: "Presenter Notes...",
                text: $question.presenterNotes,
                icon: "long.text.page.and.pencil",
                isVertical: true,
                accessibilityLabel: "Presenter notes",
                fieldID: "presenterNotes"
            )
        }
    }
}

// MARK: - Music Body
private var musicBody: some View {
    VStack(spacing: 10) {
        labeledTextField(
            title: "Title...",
            text: $question.title,
            icon: "music.note",
            accessibilityLabel: "Song title",
            validationRules: ValidationPresets.musicTitle,
            fieldID: "title"
        )

        labeledTextField(
            title: "Artist...",
            text: $question.artist,
            icon: "music.microphone",
            accessibilityLabel: "Artist name",
            validationRules: ValidationPresets.artistName,
            fieldID: "artist"
        )

        HStack(alignment: .center, spacing: 10) {
            labeledTextField(
                title: "Song URL...",
                text: $question.songURL,
                icon: "link",
                accessibilityLabel: "Song URL",
                validationRules: ValidationPresets.spotifyURL,
                fieldID: "songURL"
            )

            Button {
                // Clear focus to ensure latest field values are captured
                focusedField = nil
                // Small delay to allow binding to update
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    searchSpotifyForSong()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(question.songURL.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Search Spotify by title and artist to get URL"
                : "Get song title and artist from this Spotify URL")
            .accessibilityLabel("Search Spotify")

            labeledTextField(
                title: "Start",
                text: $question.startTime,
                icon: "play.circle",
                width: 80,
                accessibilityLabel: "Start time",
                validationRules: ValidationPresets.timeInput,
                fieldID: "startTime"
            )
            labeledTextField(
                title: "Stop",
                text: $question.stopTime,
                icon: "stop.circle",
                width: 80,
                accessibilityLabel: "Stop time",
                validationRules: ValidationPresets.timeInput,
                fieldID: "stopTime"
            )
        }
        
        HStack(spacing: 10) {
            let isThisQuestionPlaying = spotifyController.currentlyPlayingQuestionID == question.id
            
            Button {
                if isThisQuestionPlaying {
                    spotifyController.pause()
                } else {
                    spotifyController.playTrack(
                        url: question.songURL,
                        startTime: question.startTime,
                        stopTime: question.stopTime,
                        questionID: question.id
                    )
                }
            } label: {
                HStack {
                    Image(systemName: isThisQuestionPlaying ? "stop.fill" : "play.fill")
                    Text(isThisQuestionPlaying ? "Stop Song" : "Play Song")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isThisQuestionPlaying ? .red : .green)
            .disabled(question.songURL.isEmpty || question.startTime.isEmpty || question.stopTime.isEmpty)
            .help(question.songURL.isEmpty ? "Enter song URL and times first" : "Preview this music question")
            .accessibilityLabel(isThisQuestionPlaying ? "Stop song" : "Play song")
        }
        
        if let error = spotifyController.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
            }
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }

        if question.showPresenterNotes {
            labeledTextField(
                title: "Presenter Notes...",
                text: $question.presenterNotes,
                icon: "long.text.page.and.pencil",
                isVertical: true,
                accessibilityLabel: "Presenter notes",
                fieldID: "presenterNotes"
            )
        }
    }
}

// MARK: - Helper Views
private func labeledTextField(
    title: String,
    text: Binding<String>,
    icon: String,
    isVertical: Bool = false,
    width: CGFloat? = nil,
    accessibilityLabel: String,
    alwaysItalic: Bool = false,
    alwaysSecondary: Bool = false,
    hasError: Bool = false,
    validationRules: [ValidationRule] = [],
    fieldID: String? = nil
) -> some View {
    LabeledContent {
        StyledDeferredTextField(
            title: title,
            text: text,
            axis: isVertical ? .vertical : .horizontal,
            validationRules: validationRules,
            fieldID: fieldID,
            focusedField: $focusedField,
            hasError: hasError,
            alwaysItalic: alwaysItalic,
            alwaysSecondary: alwaysSecondary
        )
        .frame(width: width)
        .accessibilityLabel(accessibilityLabel)
    } label: {
        Image(systemName: icon)
            .foregroundStyle(.secondary)
            .font(.title2)
            .frame(width: 28, alignment: .center)
            .accessibilityHidden(true)
    }
}

// MARK: - Format Menus

private var formatMenu: some View {
    Group {
        formatButton(for: .standard)
        formatButton(for: .connection)
        formatButton(for: .tiebreaker)
    }
}

private var musicRoundFormatMenu: some View {
    Group {
        musicRoundFormatButton(for: .musicQuestion, label: "Music Question")
        musicRoundFormatButton(for: .connection, label: "Connection")
        musicRoundFormatButton(for: .tiebreaker, label: "Tiebreaker")
    }
}

private var beforeAndAfterRoundFormatMenu: some View {
    Group {
        musicRoundFormatButton(for: .beforeAndAfter, label: "Before & After")
        musicRoundFormatButton(for: .connection, label: "Connection")
        musicRoundFormatButton(for: .tiebreaker, label: "Tiebreaker")
    }
}

private var crosswordRoundFormatMenu: some View {
    Group {
        musicRoundFormatButton(for: .crosswordClue, label: "Crossword Clue")
        musicRoundFormatButton(for: .connection, label: "Connection")
        musicRoundFormatButton(for: .tiebreaker, label: "Tiebreaker")
    }
}

private func formatButton(for format: QuestionFormat) -> some View {
    Toggle(isOn: Binding(
        get: { question.format == format },
        set: { if $0 { question.format = format } }
    )) {
        Text(format.rawValue)
    }
}

private func musicRoundFormatButton(for format: QuestionFormat, label: String) -> some View {
    Toggle(isOn: Binding(
        get: { question.format == format },
        set: { if $0 { question.format = format } }
    )) {
        Text(label)
    }
}

// MARK: - Spotify Search

/// Bidirectional Spotify search:
/// - If songURL is empty: searches by title/artist and fills in the URL
/// - If songURL has a value: fetches metadata and fills in title/artist
private func searchSpotifyForSong() {
    let urlIsEmpty = question.songURL.trimmingCharacters(in: .whitespaces).isEmpty

    if urlIsEmpty {
        // Forward search: title + artist → URL
        spotifyController.searchAndGetTrackURL(
            title: question.title,
            artist: question.artist
        ) { [self] url in
            if let url = url {
                question.songURL = url
            }
        }
    } else {
        // Reverse search: URL → title + artist
        spotifyController.getTrackMetadata(url: question.songURL) { [self] metadata in
            if let (title, artist) = metadata {
                question.title = title
                question.artist = artist
            }
        }
    }
}

private func pointsFieldValidationValue(isFocused: Bool) -> Double? {
    if isFocused {
        let trimmed = localPointsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }
    return question.points
}

private func commitPointsField() {
    let trimmed = localPointsText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let enteredPoints = Double(trimmed) else {
        syncPointsFieldFromModel()
        return
    }

    guard TriviaValidator.validatePoints(enteredPoints) == nil else {
        syncPointsFieldFromModel()
        return
    }

    question.points = enteredPoints
    syncPointsFieldFromModel()
}

private func syncPointsFieldFromModel() {
    localPointsText = formatPoints(question.points)
}

private func formatPoints(_ points: Double) -> String {
    if points == points.rounded() {
        return String(Int(points))
    }
    return points.formatted(.number.precision(.fractionLength(1)))
}
}

// MARK: - Styled Deferred Text Field

/// A styled text field that buffers input locally and only writes to the binding on focus loss or submit.
/// This prevents per-keystroke mutations from propagating up through the document binding chain,
/// while keeping styling responsive to the local text state.
private struct StyledDeferredTextField: View {
    let title: String
    @Binding var text: String
    let axis: Axis
    let validationRules: [ValidationRule]
    let fieldID: String?
    var focusedField: FocusState<String?>.Binding
    let hasError: Bool
    let alwaysItalic: Bool
    let alwaysSecondary: Bool

    @State private var localText: String = ""

    private var isFieldFocused: Bool {
        fieldID != nil && focusedField.wrappedValue == fieldID
    }

    var body: some View {
        TextField(title, text: $localText, axis: axis)
            .textFieldStyle(.plain)
            .focused(focusedField, equals: fieldID)
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        hasError ? Color.red : (isFieldFocused ? Color.accentColor : Color.secondary.opacity(0.35)),
                        lineWidth: hasError || isFieldFocused ? 2 : 1
                    )
            )
            .foregroundStyle(hasError ? .red : (alwaysSecondary ? .secondary : (localText.isEmpty ? .secondary : .primary)))
            .italic(alwaysItalic || localText.isEmpty)
            .onAppear { localText = text }
            .onChange(of: text) { _, newValue in
                if !isFieldFocused { localText = newValue }
            }
            .onChange(of: localText) { _, newValue in
                let validated = validationRules.reduce(newValue) { $1.apply(to: $0) }
                if validated != newValue {
                    localText = validated
                } else {
                    text = validated
                }
            }
            .onSubmit { text = localText }
            .onChange(of: isFieldFocused) { _, focused in
                if !focused { text = localText }
                else { localText = text }
            }
    }
}
