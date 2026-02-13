//  TriviaDocument.swift
//  BulldogTrivia

//  Handles file saving and loading logic.

//  Created by Asa Foster // 2026

import SwiftUI
import os
@preconcurrency import UniformTypeIdentifiers

// MARK: - Custom File Type
extension UTType {
static var triviaGame: UTType {
    UTType(exportedAs: "com.bulldogtrivia.game", conformingTo: .json)
}
}

// MARK: - Document Logic
struct TriviaDocument: FileDocument {
static var readableContentTypes: [UTType] { [.triviaGame] }

var gameData: TriviaGameData

// INIT: Create a new document with minimal defaults
init() {
    // 1. Generate 6 empty questions
    let defaultQuestions = (0..<6).map { _ in
        Question(format: .standard, text: "", answer: "", points: 1.0)
    }

    // 2. Create the initial game data
    self.gameData = TriviaGameData(
        rounds: [
            Round(
                name: "Standard Q&A",
                format: .standard,
                questions: defaultQuestions
            )
        ],
        teams: [
            Team(name: "New Team")
        ]
    )
}

// LOAD: Read JSON from disk with error recovery
init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
        AppLogger.document.error("Failed to read file contents - file may be corrupted or empty")
        throw TriviaError.documentCorrupted("File contents could not be read")
    }

    do {
        let decodedData = try JSONDecoder().decode(TriviaGameData.self, from: data)
        self.gameData = decodedData
        let roundCount = decodedData.rounds.count
        let teamCount = decodedData.teams.count
        AppLogger.document.info("Document loaded successfully with \(roundCount) rounds and \(teamCount) teams")
    } catch let decodingError as DecodingError {
        // Provide detailed error information for debugging
        let errorDescription: String
        switch decodingError {
        case .typeMismatch(let type, let context):
            errorDescription = "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            errorDescription = "Missing value of type \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .keyNotFound(let key, let context):
            errorDescription = "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            errorDescription = "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
            errorDescription = decodingError.localizedDescription
        }

        AppLogger.document.error("Document decoding failed: \(errorDescription, privacy: .public)")
        throw TriviaError.documentLoadFailed(errorDescription)
    } catch {
        AppLogger.document.error("Unknown error loading document: \(error.localizedDescription, privacy: .public)")
        throw TriviaError.documentLoadFailed(error.localizedDescription)
    }
}

// SAVE: Write JSON to disk
func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    // Sanitize data before saving to remove orphaned scores
    sanitizeData()

    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(gameData)
    return FileWrapper(regularFileWithContents: data)
}

/// Removes orphaned data before saving.
/// This prevents file bloat from deleted rounds that still have team scores.
private mutating func sanitizeData() {
    // Build set of valid round IDs
    let validRoundIDs = Set(gameData.rounds.map { $0.id })

    // Remove scores for rounds that no longer exist
    for i in gameData.teams.indices {
        gameData.teams[i].scores = gameData.teams[i].scores.filter { scoreEntry in
            validRoundIDs.contains(scoreEntry.key)
        }
    }

    AppLogger.document.debug("Data sanitization complete")
}
}
