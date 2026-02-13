//  RoundEditorView.swift
//  BulldogTrivia

//  The Detail view that displays the list of editable questions.

//  Created by Asa Foster on 1/20/26.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct RoundEditorView: View {
@Binding var round: Round
let index: Int
@EnvironmentObject var presentationController: PresentationController

@State private var draggingQuestionID: UUID?
@State private var isEditingRoundName: Bool = false
@State private var editingRoundName: String = ""
@FocusState private var isRoundNameFocused: Bool

var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack(alignment: .center) {
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
                
                Picker("Format:", selection: $round.format) {
                    ForEach(RoundFormat.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: round.format) { oldValue, newValue in
                    normalizeQuestions(from: oldValue, to: newValue)
                    // Update round name if it still has the old format's default name
                    if round.name == oldValue.rawValue {
                        round.name = newValue.rawValue
                    }
                }
                .accessibilityLabel("Round format")
                .accessibilityHint("Select the question format for this round")
            }
            .padding(.horizontal, 18)
            .padding(.top, 32)
            .padding(.bottom, 6)
            
            // Question stack
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
                
                addQuestionButton(roundFormat: round.format)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }
    .onAppear {
        clearFocus()
    }
    .onTapGesture {
        if isEditingRoundName {
            commitRoundNameEdit()
        }
    }
}

/// Clears focus from any text field
private func clearFocus() {
    DispatchQueue.main.async {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

private func addQuestionButton(roundFormat: RoundFormat) -> some View {
    Button {
        switch roundFormat {
        case .music:
            round.questions.append(
                Question(
                    format: .musicQuestion,
                    text: "", answer: "", points: 1.0,
                    title: "", artist: "", titlePoints: 1.0, artistPoints: 1.0
                )
            )
        case .crossword:
            round.questions.append(
                Question(format: .crosswordClue, text: "", answer: "", points: 1.0)
            )
        case .standard:
            round.questions.append(
                Question(format: .standard, text: "", answer: "", points: 1.0)
            )
        case .beforeAndAfter:
            round.questions.append(
                Question(format: .beforeAndAfter, text: "", answer: "", points: 1.0)
            )
        }
    } label: {
        Label("Add Question", systemImage: "plus.circle")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }
    .buttonStyle(.plain)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.separator.opacity(0.35), lineWidth: 1)
    )
    .accessibilityLabel("Add new question")
    .accessibilityHint("Adds a new question to the round")
}

private func normalizeQuestions(from oldFormat: RoundFormat, to newFormat: RoundFormat) {
    for i in round.questions.indices {
        let q = round.questions[i]
        
        if q.format == .connection || q.format == .tiebreaker {
            continue
        }
        
        switch newFormat {
        case .music:
            if round.questions[i].title.isEmpty && !q.text.isEmpty {
                round.questions[i].title = q.text
            }
            round.questions[i].format = .musicQuestion
            
        case .crossword:
            if round.questions[i].text.isEmpty && !q.title.isEmpty {
                round.questions[i].text = q.title
            }
            if round.questions[i].crosswordRevealIndex == nil {
                round.questions[i].crosswordRevealIndex = "1"
            }
            round.questions[i].format = .crosswordClue

        case .standard:
            if round.questions[i].text.isEmpty && !q.title.isEmpty {
                round.questions[i].text = q.title
            }
            round.questions[i].format = .standard

        case .beforeAndAfter:
            // For Before & After, text becomes clue 1, artist becomes clue 2
            if round.questions[i].text.isEmpty && !q.title.isEmpty {
                round.questions[i].text = q.title
            }
            // Keep artist field for clue 2 (if coming from music, preserve it)
            round.questions[i].format = .beforeAndAfter
        }
    }
}

private func commitRoundNameEdit() {
    round.name = editingRoundName
    isEditingRoundName = false
    isRoundNameFocused = false
}

private func isQuestionHighlighted(questionIndex: Int) -> Bool {
    guard let currentSlide = presentationController.currentSlide else { return false }
    
    switch currentSlide.type {
    case .question(let roundIndex, let qIndex):
        return roundIndex == index && qIndex == questionIndex
    case .answer(let roundIndex, let qIndex):
        return roundIndex == index && qIndex == questionIndex
    default:
        return false
    }
}
}
