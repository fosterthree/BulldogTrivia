//  AllRoundsEditorView.swift
//  BulldogTrivia
//
//  Shows all rounds in a single scrollable column.
//
//  Created by Asa Foster // 2026

import SwiftUI

struct AllRoundsEditorView: View {
    @Binding var document: TriviaDocument
    @EnvironmentObject var presentationController: PresentationController
    @Binding var expandedRounds: Set<Round.ID>
    @Binding var scrollTarget: Round.ID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(document.gameData.rounds.indices, id: \.self) { idx in
                        RoundSection(
                            round: $document.gameData.rounds[idx],
                            index: idx,
                            isExpanded: Binding(
                                get: { expandedRounds.contains(document.gameData.rounds[idx].id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedRounds.insert(document.gameData.rounds[idx].id)
                                    } else {
                                        expandedRounds.remove(document.gameData.rounds[idx].id)
                                    }
                                }
                            ),
                            onDelete: {
                                deleteRound(at: idx)
                            },
                            gameData: $document.gameData
                        )
                        .id(document.gameData.rounds[idx].id)
                    }

                    // Add Round button
                    Button(action: addRound) {
                        Label("Add Round", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .accessibilityLabel("Add new round")
                }
                .padding()
            }
            .onChange(of: scrollTarget) { _, newTarget in
                if let target = newTarget {
                    // Expand the target round
                    expandedRounds.insert(target)

                    // Scroll to it
                    withAnimation {
                        proxy.scrollTo(target, anchor: .top)
                    }

                    // Clear the target after scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollTarget = nil
                    }
                }
            }
        }
    }

    private func addRound() {
        // Create 6 default questions
        let defaultQuestions = (0..<6).map { _ in
            Question(format: .standard, text: "", answer: "", points: 1.0)
        }

        let newRound = Round(name: "Standard Q&A", format: .standard, questions: defaultQuestions)
        document.gameData.rounds.append(newRound)
        expandedRounds.insert(newRound.id)

        // Regenerate slides
        presentationController.generateSlides(from: document.gameData)
    }

    private func deleteRound(at index: Int) {
        let roundID = document.gameData.rounds[index].id
        document.gameData.rounds.remove(at: index)
        expandedRounds.remove(roundID)

        // Regenerate slides
        presentationController.generateSlides(from: document.gameData)
    }
}

