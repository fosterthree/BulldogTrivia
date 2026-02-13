//  Logger.swift
//  BulldogTrivia

//  Centralized logging using OSLog for proper system integration.

//  Created by Asa Foster // 2026

import Foundation
import OSLog

/// Centralized logging facility for BulldogTrivia.
enum AppLogger {

// MARK: - Subsystem

static let subsystem = Bundle.main.bundleIdentifier ?? "com.bulldogtrivia"

// MARK: - Logger Instances

/// Logger for presentation-related events
static let presentation = Logger(subsystem: subsystem, category: "Presentation")

/// Logger for Spotify integration
static let spotify = Logger(subsystem: subsystem, category: "Spotify")

/// Logger for document operations
static let document = Logger(subsystem: subsystem, category: "Document")

/// Logger for UI events
static let ui = Logger(subsystem: subsystem, category: "UI")

/// Logger for data validation errors
static let validation = Logger(subsystem: subsystem, category: "Validation")

/// Logger for general app lifecycle events
static let app = Logger(subsystem: subsystem, category: "App")
}

// MARK: - Convenience Extensions

extension Logger {

/// Logs a warning message.
func warning(_ message: String) {
    self.error("⚠️ WARNING: \(message, privacy: .public)")
}

/// Logs an error with associated `TriviaError` details.
func log(error: TriviaError) {
    self.error("""
        TriviaError: \(error.localizedDescription, privacy: .public)
        Recovery: \(error.recoverySuggestion ?? "None", privacy: .public)
        """)
}

/// Logs the start of an operation for performance tracking.
func logOperationStart(_ operation: String) -> OSSignpostID {
    let signpostID = OSSignpostID(log: OSLog(subsystem: AppLogger.subsystem, category: "Performance"))
    os_signpost(.begin, log: OSLog(subsystem: AppLogger.subsystem, category: "Performance"), name: "Operation", signpostID: signpostID, "%{public}s", operation)
    return signpostID
}

/// Logs the end of an operation for performance tracking.
func logOperationEnd(_ operation: String, signpostID: OSSignpostID) {
    os_signpost(.end, log: OSLog(subsystem: AppLogger.subsystem, category: "Performance"), name: "Operation", signpostID: signpostID, "%{public}s completed", operation)
}
}
