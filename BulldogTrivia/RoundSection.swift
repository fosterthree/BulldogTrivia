//  RoundSection.swift
//  BulldogTrivia
//
//  A collapsible section for editing a single round.
//
//  Created by Asa Foster // 2026

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct RoundSection: View {
    @Binding var round: Round
    let index: Int
    @Binding var isExpanded: Bool
    let onDelete: () -> Void
    @Binding var gameData: TriviaGameData

    @EnvironmentObject var presentationController: PresentationController
    @State private var draggingQuestionID: UUID?
    @State private var isEditingRoundName: Bool = false
    @State private var editingRoundName: String = ""
    @FocusState private var isRoundNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Round header
            roundHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

            // Questions (when expanded)
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(round.questions.indices, id: \.self) { i in
                        let qID = round.questions[i].id
                        let isHighlighted = isQuestionHighlighted(questionIndex: i)

                        QuestionCard(
                            number: i + 1,
                            question: $round.questions[i],
                            roundFormat: round.format,
                            isHighlighted: isHighlighted,
                            onDelete: {
                                round.questions.removeAll { $0.id == qID }
                            }
                        )
                        .onDrag {
                            draggingQuestionID = qID
                            return NSItemProvider(object: qID.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: QuestionReorderDropDelegate(
                                targetID: qID,
                                questions: $round.questions,
                                draggingID: $draggingQuestionID
                            )
                        )
                        .onTapGesture {
                            if isEditingRoundName {
                                commitRoundNameEdit()
                            }
                        }
                    }

                    // Add question button
                    Button(action: addQuestion) {
                        Label("Add Question", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .accessibilityLabel("Add question to round \(index + 1)")
                }
                .padding(.horizontal, 18)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var roundHeader: some View {
        HStack(alignment: .center) {
            // Disclosure indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            Label {
                HStack(spacing: 4) {
                    Text("Round \(index + 1):")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if isEditingRoundName {
                        TextField("Round Name", text: $editingRoundName)
                            .textFieldStyle(.roundedBorder)
                            .font(.title.weight(.semibold))
                            .focused($isRoundNameFocused)
                            .onAppear {
                                editingRoundName = round.name
                                isRoundNameFocused = true
                            }
                            .onSubmit {
                                commitRoundNameEdit()
                            }
                            .onChange(of: isRoundNameFocused) { _, isFocused in
                                if !isFocused && isEditingRoundName {
                                    commitRoundNameEdit()
                                }
                            }
                            .accessibilityLabel("Round name")
                    } else {
                        Text(round.name)
                            .font(.title.weight(.semibold))
                            .onTapGesture {
                                isEditingRoundName = true
                                editingRoundName = round.name
                            }
                            .accessibilityLabel("Round name: \(round.name)")
                            .accessibilityHint("Double-tap to edit")
                    }
                }
            } icon: {
                Image(systemName: round.format.symbol)
                    .foregroundStyle(.tint)
                    .font(.title)
            }

            Spacer()

            // Format picker
            Picker("Format:", selection: $round.format) {
                ForEach(RoundFormat.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: round.format) { oldValue, newValue in
                round.normalizeQuestions(to: newValue)
                // Update round name if it still has the old format's default name
                if round.name == oldValue.rawValue {
                    round.name = newValue.rawValue
                }
                // Update just the round icon (much faster than regenerating all slides)
                presentationController.updateRoundIcon(roundID: round.id, newFormat: newValue)
            }
            .accessibilityLabel("Round format")
            .accessibilityHint("Select the question format for this round")

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete round \(index + 1)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private func isQuestionHighlighted(questionIndex: Int) -> Bool {
        guard let currentSlide = presentationController.currentSlide else {
            return false
        }

        switch currentSlide.type {
        case .question(let roundIndex, let qIndex), .answer(let roundIndex, let qIndex):
            return roundIndex == index && qIndex == questionIndex
        default:
            return false
        }
    }

    private func addQuestion() {
        round.addDefaultQuestion()
    }

    private func commitRoundNameEdit() {
        round.name = editingRoundName.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingRoundName = false
        isRoundNameFocused = false
    }
}
