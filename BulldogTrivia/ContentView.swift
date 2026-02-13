//  ContentView.swift
//  BulldogTrivia

//  The main view glue.

//  Created by Asa Foster // 2026

import SwiftUI

struct ContentView: View {
enum TopTab: String, CaseIterable, Identifiable {
    case gameSetup = "Game Setup"
    case teams = "Teams & Scoring"
    var id: String { rawValue }
}

@Binding var document: TriviaDocument
@EnvironmentObject var presentationController: PresentationController
@Environment(\.openWindow) private var openWindow

@State private var topTab: TopTab = .gameSetup
@State private var expandedRounds: Set<Round.ID>
@State private var scrollTarget: Round.ID?
@State private var errorAlert: ErrorAlert?
@State private var regenerationTask: Task<Void, Never>?
@State private var cachedTiebreakerAnswer: Double?
@Binding var showSidebarPreview: Bool

init(document: Binding<TriviaDocument>, showSidebarPreview: Binding<Bool>) {
    self._document = document
    self._showSidebarPreview = showSidebarPreview
    // Initialize expandedRounds with all round IDs to prevent re-expansion on appear
    self._expandedRounds = State(initialValue: Set(document.wrappedValue.gameData.rounds.map { $0.id }))
    // Initialize cached tiebreaker answer
    self._cachedTiebreakerAnswer = State(initialValue: extractTiebreakerAnswer(from: document.wrappedValue.gameData))
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let suggestion: String?
    
    init(title: String, message: String, suggestion: String? = nil) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
    }
    
    init(error: TriviaError) {
        self.title = "Validation Issue"
        self.message = error.localizedDescription
        self.suggestion = error.recoverySuggestion
    }
}

var body: some View {
    NavigationSplitView {
        sidebarContent
            .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 500)
    } detail: {
        Group {
            switch topTab {
            case .gameSetup:
                gameSetupTab
            case .teams:
                TeamsView(
                    teams: $document.gameData.teams,
                    rounds: document.gameData.rounds,
                    correctTiebreakerAnswer: cachedTiebreakerAnswer
                )
            }
        }
        .overlay(alignment: .top) {
            Divider()
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(.container, edges: .horizontal)
                .allowsHitTesting(false)
        }
    }
    .frame(minWidth: 1000, idealWidth: 1600, maxWidth: .infinity,
           minHeight: 700, idealHeight: 1200, maxHeight: .infinity)
    .onTapGesture {
        // Unfocus all text fields when tapping outside
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
    .toolbar {
        ToolbarItem(placement: .principal) {
            Picker("Navigation", selection: $topTab) {
                ForEach(TopTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
            .accessibilityLabel("Navigation tabs")
        }
    }
    .alert(item: $errorAlert) { alert in
        Alert(
            title: Text(alert.title),
            message: Text(alert.message + (alert.suggestion.map { "\n\n\($0)" } ?? "")),
            dismissButton: .default(Text("OK"))
        )
    }
    .onAppear {
        validateDocumentData()

        // Generate slides on initial load
        presentationController.generateSlides(from: document.gameData)
    }
    .onChange(of: document.gameData) { _, newData in
        // Update cached tiebreaker answer
        cachedTiebreakerAnswer = extractTiebreakerAnswer(from: newData)

        // Debounce slide regeneration to avoid excessive updates during rapid edits
        regenerationTask?.cancel()
        regenerationTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                presentationController.updateData(newData)
            }
        }
    }
    .onDisappear {
        regenerationTask?.cancel()
        regenerationTask = nil
    }
}

// MARK: - Sidebar Content

private var sidebarContent: some View {
    VStack(spacing: 0) {
        Color.clear.frame(height: 32)

        // Presentation Control Panel (slide list)
        PresentationControlPanel(
            document: $document,
            scrollTarget: $scrollTarget,
            topTab: $topTab,
            showPreview: $showSidebarPreview
        )
        .frame(maxHeight: .infinity)
    }
    .background(.regularMaterial)
    .overlay(Color.black.opacity(0.04).allowsHitTesting(false))
    .overlay(alignment: .trailing) {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1)
            .allowsHitTesting(false)
    }
    .ignoresSafeArea(.container, edges: .top)
}

private var gameSetupTab: some View {
    AllRoundsEditorView(
        document: $document,
        expandedRounds: $expandedRounds,
        scrollTarget: $scrollTarget
    )
}

// MARK: - Helpers

/// Validates document data and shows alerts if issues are found
private func validateDocumentData() {
    // Check for empty rounds
    if let error = TriviaValidator.validateRoundsForEmptyQuestions(document.gameData.rounds) {
        // Only show if there are multiple rounds (don't alert on fresh document)
        if document.gameData.rounds.count > 1 {
            errorAlert = ErrorAlert(error: error)
            return
        }
    }
    
    // Check for duplicate team names
    if let error = TriviaValidator.validateTeamsForDuplicates(document.gameData.teams) {
        errorAlert = ErrorAlert(error: error)
        return
    }
}
}
