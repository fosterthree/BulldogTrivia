//  TeamsView.swift
//  BulldogTrivia

//  The main spreadsheet view for scoring.
//  Uses standard macOS styling and QuestionCard aesthetics.

//  Created by Asa Foster // 2026

import SwiftUI
import os

struct TeamsView: View {
    @Binding var teams: [Team]
    let rounds: [Round]
    let correctTiebreakerAnswer: Double?
    
    // Layout constants
    private let rankWidth: CGFloat = 50
    private let scoreWidth: CGFloat = 60
    private let totalWidth: CGFloat = 100
    private let tiebreakerWidth: CGFloat = 100
    
    /// Cached display order - only updates when explicitly requested
    @State private var displayOrder: [UUID] = []
    
    /// Sort configuration
    @State private var sortBy: SortColumn = .rank
    @State private var sortAscending: Bool = true
    
    @FocusState private var focusedField: String?
    
    enum SortColumn {
        case rank
        case name
    }
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                
                // 1. Header Row
                headerRow
                    .padding(.bottom, 10)
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                
                // 2. Team Rows (displayed in stable order, ranks calculated dynamically)
                LazyVStack(spacing: 12) {
                    ForEach(displayedTeams, id: \.team.id) { item in
                        if let teamBinding = binding(for: item.team) {
                            teamCard(for: teamBinding, rank: item.rank)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                
                // 3. Add Team Button
                Button(action: addTeam) {
                    Label("Add Team", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AnyShapeStyle(.separator.opacity(0.35)), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
                .accessibilityLabel("Add new team")
                .accessibilityHint("Creates a new team with default settings")
            }
        }
        .onAppear {
            initializeDisplayOrder()
        }
        .onChange(of: teams.count) { _, _ in
            // Update display order when teams are added or removed
            syncDisplayOrder()
        }
    }
    
    // MARK: - Subviews
    
    private var headerRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            // Rank Header (sortable)
            Button {
                toggleSort(for: .rank)
            } label: {
                HStack(spacing: 4) {
                    headerLabel("Rank")
                    if sortBy == .rank {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: rankWidth, alignment: .center)
            .accessibilityLabel("Sort by rank")
            
            // Divider Spacer
            Color.clear.frame(width: 1, height: 20)
            
            // Team Name Header (sortable)
            Button {
                toggleSort(for: .name)
            } label: {
                HStack(spacing: 4) {
                    headerLabel("Team Name")
                    if sortBy == .name {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .accessibilityLabel("Sort by team name")
            
            // Dynamic Rounds
            ForEach(rounds.indices, id: \.self) { i in
                headerLabel("R\(i + 1)")
                    .frame(width: scoreWidth, alignment: .center)
            }
            
            // Tiebreaker
            headerLabel("TIE")
                .frame(width: tiebreakerWidth, alignment: .center)
            
            // Total
            headerLabel("TOTAL")
                .frame(width: totalWidth, alignment: .center)
        }
        .padding(.horizontal, 14)
    }
    
    private func teamCard(for team: Binding<Team>, rank: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            
            // 1. Leading Icon (Calculated Rank)
            VStack {
                Spacer(minLength: 0)
                
                ZStack {
                    Image(systemName: "circle.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.background)
                }
                .frame(width: rankWidth)
                .accessibilityLabel("Rank \(rank)")
                
                Spacer(minLength: 0)
            }
            
            // 2. Vertical Divider
            Divider()
                .frame(width: 1)
                .padding(.vertical, -8)
                .allowsHitTesting(false)
            
            // 3. Team Name with validation
            let nameFieldID = "teamName-\(team.wrappedValue.id)"
            styledField(width: nil, fieldID: nameFieldID) {
                TextField("Team Name", text: team.name)
                    .focused($focusedField, equals: nameFieldID)
                    .accessibilityLabel("Team name")
                    .validated(text: team.name, rules: ValidationPresets.teamName)
            }
            .frame(maxWidth: .infinity)
            
            // 4. Round Scores
            ForEach(rounds) { round in
                let scoreFieldID = "score-\(round.id.uuidString)-\(team.wrappedValue.id)"
                styledField(width: scoreWidth, fieldID: scoreFieldID) {
                    DeferredNumberField(
                        placeholder: "0",
                        initialValue: team.wrappedValue.scores[round.id] ?? 0,
                        alignment: .center,
                        fieldID: scoreFieldID,
                        focusedField: $focusedField
                    ) { newValue in
                        if let v = newValue {
                            team.wrappedValue.scores[round.id] = max(0, v)
                        } else {
                            team.wrappedValue.scores[round.id] = 0
                        }
                    }
                }
            }
            
            // 5. Tiebreaker Answer (with bounds validation)
            let tieFieldID = "tiebreaker-\(team.wrappedValue.id)"
            styledField(width: tiebreakerWidth, fieldID: tieFieldID) {
                DeferredNumberField(
                    placeholder: "—",
                    initialValue: team.wrappedValue.tiebreakerAnswer,
                    alignment: .center,
                    fieldID: tieFieldID,
                    focusedField: $focusedField
                ) { newValue in
                    if let value = newValue {
                        let clampedValue = min(
                            max(value, TriviaSchemaConstants.tiebreakerMinValue),
                            TriviaSchemaConstants.tiebreakerMaxValue
                        )
                        team.wrappedValue.tiebreakerAnswer = clampedValue
                    } else {
                        team.wrappedValue.tiebreakerAnswer = nil
                    }
                }
            }
            
            // 6. Total
            styledField(width: totalWidth, fieldID: nil) {
                Text(team.wrappedValue.totalScore(rounds: rounds).formatted())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                    .accessibilityLabel("Total score: \(team.wrappedValue.totalScore(rounds: rounds).formatted())")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AnyShapeStyle(.separator.opacity(0.35)), lineWidth: 1)
        )
        .contextMenu {
            Button("Delete Team", systemImage: "trash", role: .destructive) {
                deleteTeam(team.wrappedValue)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func headerLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
    
    private func styledField<Content: View>(width: CGFloat?, fieldID: String?, hasError: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .textFieldStyle(.plain)
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        hasError
                            ? AnyShapeStyle(Color.red)
                            : ((fieldID != nil && focusedField == fieldID)
                               ? AnyShapeStyle(Color.accentColor)
                               : AnyShapeStyle(Color.secondary.opacity(0.35))),
                        lineWidth: (hasError || (fieldID != nil && focusedField == fieldID)) ? 2 : 1
                    )
            )
            .frame(width: width)
    }
    
    // MARK: - Deferred Number Field

    /// A numeric TextField that buffers edits locally and commits on submit or focus loss.
    private struct DeferredNumberField: View {
        let placeholder: String
        let initialValue: Double?
        let alignment: TextAlignment
        let fieldID: String
        var focusedField: FocusState<String?>.Binding
        let onCommit: (Double?) -> Void

        @State private var localText: String = ""

        private var isFocused: Bool { focusedField.wrappedValue == fieldID }

        var body: some View {
            TextField(placeholder, text: $localText)
                .multilineTextAlignment(alignment)
                .monospacedDigit()
                .focused(focusedField, equals: fieldID)
                .onAppear {
                    localText = formatted(initialValue)
                }
                .onChange(of: isFocused) { _, nowFocused in
                    if !nowFocused {
                        commit()
                    }
                }
                .onSubmit {
                    commit()
                }
        }

        private func commit() {
            let trimmed = localText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                onCommit(nil)
                return
            }
            if let number = Double(trimmed) {
                onCommit(number)
            } else {
                // Invalid input: do not commit; keep previous value.
            }
        }

        private func formatted(_ value: Double?) -> String {
            guard let value else { return "" }
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(value))
            }
            return String(value)
        }
    }
    
    // MARK: - Logic
    
    /// Teams displayed with dynamically calculated ranks, sorted by current sort settings.
    private var displayedTeams: [(team: Team, rank: Int)] {
        // Build rank lookup using shared ranking logic
        let rankedTeams = teams.withRanks(rounds: rounds, correctTiebreakerAnswer: correctTiebreakerAnswer)
        let rankLookup = Dictionary(uniqueKeysWithValues: rankedTeams.map { ($0.team.id, $0.rank) })
        
        // Get teams with their ranks
        var teamsWithRanks = displayOrder.compactMap { id -> (team: Team, rank: Int)? in
            guard let team = teams.first(where: { $0.id == id }),
                  let rank = rankLookup[id] else { return nil }
            return (team, rank)
        }
        
        // Apply sorting
        teamsWithRanks.sort { t1, t2 in
            let comparison: Bool
            switch sortBy {
            case .rank:
                comparison = t1.rank < t2.rank
            case .name:
                comparison = t1.team.name.localizedStandardCompare(t2.team.name) == .orderedAscending
            }
            return sortAscending ? comparison : !comparison
        }
        
        return teamsWithRanks
    }
    
    /// Initializes display order from current teams array
    private func initializeDisplayOrder() {
        if displayOrder.isEmpty {
            displayOrder = teams.map { $0.id }
        }
    }
    
    /// Syncs display order when teams are added or removed
    private func syncDisplayOrder() {
        let currentIDs = Set(teams.map { $0.id })
        let displayIDs = Set(displayOrder)
        
        // Remove deleted teams
        displayOrder.removeAll { !currentIDs.contains($0) }
        
        // Add new teams at the end
        for team in teams where !displayIDs.contains(team.id) {
            displayOrder.append(team.id)
        }
    }
    
    /// Helper to get a Binding for a specific team (returns nil if not found)
    private func binding(for team: Team) -> Binding<Team>? {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else {
            return nil
        }
        return $teams[index]
    }
    
    private func addTeam() {
        AppLogger.ui.info("Adding new team")
        withAnimation(.snappy) {
            teams.append(Team(name: "New Team"))
        }
    }
    
    private func deleteTeam(_ team: Team) {
        AppLogger.ui.info("Deleting team: \(team.name, privacy: .public)")
        withAnimation(.snappy) {
            teams.removeAll { $0.id == team.id }
        }
    }
    
    private func toggleSort(for column: SortColumn) {
        withAnimation(.snappy) {
            if sortBy == column {
                // Toggle direction if clicking the same column
                sortAscending.toggle()
            } else {
                // Switch to new column with default ascending order
                sortBy = column
                sortAscending = column == .rank ? true : true
            }
        }
    }
    
}

