//  PresentationControlPanel.swift
//  BulldogTrivia

//  Control panel for managing the presentation from the sidebar.

//  Created by Asa Foster // 2026

import SwiftUI

struct PresentationControlPanel: View {
    @EnvironmentObject var presentationController: PresentationController
    @Binding var document: TriviaDocument
    @Binding var scrollTarget: Round.ID?
    @Binding var topTab: ContentView.TopTab
    @Binding var showPreview: Bool

    @Environment(\.openWindow) private var openWindow

    @State private var editingRoundID: UUID?
    @State private var editingRoundName: String = ""
    @FocusState private var focusedRoundID: UUID?
    @State private var selectionUpdateTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Slide List (takes all remaining vertical space)
            List {
                ForEach(presentationController.slides.indices, id: \.self) { index in
                    slideRow(for: presentationController.slides[index], at: index)
                        .listRowInsets(EdgeInsets(top: 1, leading: 14, bottom: 1, trailing: 14))
                        .listRowSeparator(.hidden)

                    // Add dividers after welcome and standings slides
                    if shouldShowDividerAfter(index: index) {
                        Divider()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
            .frame(maxHeight: .infinity)  // Allow list to expand to fill space

            // Divider between list and preview
            if showPreview {
                Divider()
            }

            // Preview Pane
            if showPreview {
                previewPane
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPreview)  // Smooth expand/collapse
        .onDisappear {
            selectionUpdateTask?.cancel()
            selectionUpdateTask = nil
        }
    }

    @ViewBuilder
    private func slideRow(for slide: PresentationSlide, at index: Int) -> some View {
        let isCurrentSlide = index == presentationController.currentSlideIndex

        Button(action: {
            handleSlideSelection(slide: slide, index: index)
        }) {
            slideLabel(for: slide, at: index, isCurrentSlide: isCurrentSlide)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(isCurrentSlide ? Color.accentColor : Color.clear)
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Show Slide", systemImage: "display") {
                openWindow(id: "presentation")
                handleDoubleClick(slide: slide, index: index)
            }
            .accessibilityLabel("Open presentation window and jump to slide \(index + 1)")
        }
        .accessibilityLabel(slideAccessibilityLabel(for: slide, at: index))
    }

    @ViewBuilder
    private func slideLabel(for slide: PresentationSlide, at index: Int, isCurrentSlide: Bool) -> some View {
        let isQuestionOrAnswer = isQuestionOrAnswerSlide(slide.type)

        HStack(spacing: 10) {
            // Show icon for all slides
            if isQuestionOrAnswer {
                // Use specific icons for Connection and Tiebreaker, bullet for others
                if let iconName = specialQuestionIcon(for: slide) {
                    Image(systemName: iconName)
                        .foregroundStyle(isCurrentSlide ? Color.white : .secondary)
                        .font(.system(size: 14))
                        .frame(width: 20)
                } else {
                    // Small bullet point for standard questions and answers (unchanged size)
                    Circle()
                        .fill(isCurrentSlide ? Color.white : Color.secondary)
                        .frame(width: 4, height: 4)
                        .frame(width: 20)
                }
            } else {
                // Regular icon for other slides
                Image(systemName: slide.icon)
                    .foregroundStyle(isCurrentSlide ? Color.white : .secondary)
                    .font(.system(size: 14))
                    .frame(width: 20)
            }

            // Handle round title slides with editable names
            if case .roundTitle = slide.type {
                roundTitleLabel(for: slide, isCurrentSlide: isCurrentSlide)
            } else {
                // Use slide.title directly - it's already computed when slides are generated
                Text(slide.title)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .foregroundStyle(isCurrentSlide ? .primary : .secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func roundTitleLabel(for slide: PresentationSlide, isCurrentSlide: Bool) -> some View {
        if case .roundTitle(let roundIndex) = slide.type,
           roundIndex < document.gameData.rounds.count {
            let round = document.gameData.rounds[roundIndex]

            HStack(spacing: 4) {
                // Non-editable prefix
                Text("Round \(roundIndex + 1):")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                // Editable round name
                if editingRoundID == round.id {
                    TextField("Round Name", text: $editingRoundName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5))
                        .focused($focusedRoundID, equals: round.id)
                        .onAppear {
                            editingRoundName = round.name
                            focusedRoundID = round.id
                        }
                        .onSubmit {
                            commitEditing(roundIndex: roundIndex)
                        }
                        .onChange(of: focusedRoundID) { oldValue, newValue in
                            if oldValue == round.id && newValue != round.id {
                                commitEditing(roundIndex: roundIndex)
                            }
                        }
                } else {
                    Text(round.name)
                        .font(.system(size: 11.5))
                        .lineLimit(1)
                        .foregroundStyle(isCurrentSlide ? .primary : .secondary)
                        .onTapGesture(count: 2) {
                            editingRoundID = round.id
                            editingRoundName = round.name
                            focusedRoundID = round.id
                        }
                }
            }
        } else {
            Text(slide.title)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .foregroundStyle(isCurrentSlide ? .primary : .secondary)
        }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        Color.clear
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                PresentationView()
                    .environmentObject(presentationController)
            )
    }


    // MARK: - Helper Methods

    private func shouldShowDividerAfter(index: Int) -> Bool {
        guard index < presentationController.slides.count else { return false }
        let slide = presentationController.slides[index]

        // Show divider after welcome slide
        if case .welcome = slide.type {
            return true
        }

        // Show divider after standings slides, but not after the last one
        if case .standings = slide.type {
            return index < presentationController.slides.count - 1
        }
        return false
    }

    // MARK: - Action Handlers

    private func handleSlideSelection(slide: PresentationSlide, index: Int) {
        // Update presentation immediately for instant visual feedback
        presentationController.jumpTo(index: index)

        // Debounce tab changes and scrolling
        selectionUpdateTask?.cancel()
        selectionUpdateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            // Switch tabs and scroll to round based on slide type
            switch slide.type {
            case .roundTitle, .question, .answer, .submitAnswers:
                if topTab != .gameSetup {
                    topTab = .gameSetup
                }
                // Scroll to the round if there is one
                if let roundID = slide.roundID {
                    scrollTarget = roundID
                }
            case .standings:
                if topTab != .teams {
                    topTab = .teams
                }
            default:
                break
            }
        }
    }

    private func handleDoubleClick(slide: PresentationSlide, index: Int) {
        // Switch tabs and scroll to round
        switch slide.type {
        case .roundTitle, .question, .answer, .submitAnswers:
            if topTab != .gameSetup {
                topTab = .gameSetup
            }
            // Scroll to the round
            if let roundID = slide.roundID {
                scrollTarget = roundID
            }
        case .standings:
            if topTab != .teams {
                topTab = .teams
            }
        default:
            break
        }

        // Jump to the selected slide
        presentationController.jumpTo(index: index)
    }

    // MARK: - Helper Functions

    private func commitEditing(roundIndex: Int? = nil) {
        // Find the round index if not provided
        if let editingID = editingRoundID {
            let idx = roundIndex ?? document.gameData.rounds.firstIndex(where: { $0.id == editingID })
            
            if let idx = idx {
                document.gameData.rounds[idx].name = editingRoundName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        editingRoundID = nil
        focusedRoundID = nil
        editingRoundName = ""
        
        presentationController.updateData(document.gameData)
    }
    
    private func isQuestionOrAnswerSlide(_ type: SlideType) -> Bool {
        switch type {
        case .question, .answer:
            return true
        default:
            return false
        }
    }

    private func specialQuestionIcon(for slide: PresentationSlide) -> String? {
        // Get the question format to determine if we should use a special icon
        switch slide.type {
        case .question(let roundIndex, let qIndex), .answer(let roundIndex, let qIndex):
            guard roundIndex < document.gameData.rounds.count,
                  qIndex < document.gameData.rounds[roundIndex].questions.count else {
                return nil
            }
            let question = document.gameData.rounds[roundIndex].questions[qIndex]
            switch question.format {
            case .connection:
                return "link"
            case .tiebreaker:
                return "bolt.fill"
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    private func slideAccessibilityLabel(for slide: PresentationSlide, at index: Int) -> String {
        let isCurrentSlide = index == presentationController.currentSlideIndex
        let currentIndicator = isCurrentSlide ? ", current slide" : ""

        switch slide.type {
        case .welcome:
            return "Welcome slide\(currentIndicator)"
        case .roundTitle(let roundIndex):
            if roundIndex < document.gameData.rounds.count {
                return "Round \(roundIndex + 1): \(document.gameData.rounds[roundIndex].name)\(currentIndicator)"
            }
            return "Round \(roundIndex + 1)\(currentIndicator)"
        case .question:
            return "\(slide.title)\(currentIndicator)"
        case .submitAnswers:
            return "Submit answers slide\(currentIndicator)"
        case .answer:
            return "\(slide.title)\(currentIndicator)"
        case .standings(let afterRound):
            if let round = afterRound {
                return "Standings after round \(round + 1)\(currentIndicator)"
            }
            return "Final standings\(currentIndicator)"
        case .rules:
            return "Rules slide\(currentIndicator)"
        case .finalResults:
            return "Final results slide\(currentIndicator)"
        case .thankYou:
            return "Thank you slide\(currentIndicator)"
        }
    }
}
