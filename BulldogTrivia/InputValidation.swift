//  InputValidation.swift
//  BulldogTrivia

//  Input validation modifiers and utilities for text fields.

//  Created by Asa Foster // 2026

import SwiftUI
import Combine

// MARK: - Validation Rules

/// Defines validation rules for text input fields.
///
/// Use these rules with the `.validated()` modifier to enforce constraints
/// on text field input in real-time.
///
/// ## Example
/// ```swift
/// TextField("Team Name", text: $teamName)
///     .validated(rules: [.maxLength(50), .noLeadingWhitespace])
/// ```
enum ValidationRule: Equatable {
/// Limits input to a maximum number of characters.
case maxLength(Int)

/// Limits input to a minimum number of characters (for display, not blocking).
case minLength(Int)

/// Removes leading whitespace as the user types.
case noLeadingWhitespace

/// Removes trailing whitespace when editing ends.
case noTrailingWhitespace

/// Prevents any whitespace characters.
case noWhitespace

/// Allows only alphanumeric characters.
case alphanumericOnly

/// Allows only numeric characters (digits).
case numericOnly

/// Allows only characters matching the provided CharacterSet.
case allowedCharacters(CharacterSet)

/// Blocks characters matching the provided CharacterSet.
case blockedCharacters(CharacterSet)

/// Custom validation with a closure (always returns true for Equatable conformance check).
case custom((String) -> String)

/// Applies the validation rule to transform the input string.
///
/// - Parameter input: The current input string.
/// - Returns: The validated/transformed string.
func apply(to input: String) -> String {
    switch self {
    case .maxLength(let max):
        return String(input.prefix(max))
        
    case .minLength:
        // Min length doesn't transform, just used for validation state
        return input
        
    case .noLeadingWhitespace:
        var result = input
        while result.first?.isWhitespace == true {
            result.removeFirst()
        }
        return result
        
    case .noTrailingWhitespace:
        var result = input
        while result.last?.isWhitespace == true {
            result.removeLast()
        }
        return result
        
    case .noWhitespace:
        return input.filter { !$0.isWhitespace }
        
    case .alphanumericOnly:
        return input.filter { $0.isLetter || $0.isNumber }
        
    case .numericOnly:
        return input.filter { $0.isNumber }
        
    case .allowedCharacters(let set):
        return input.unicodeScalars.filter { set.contains($0) }.map { String($0) }.joined()
        
    case .blockedCharacters(let set):
        return input.unicodeScalars.filter { !set.contains($0) }.map { String($0) }.joined()
        
    case .custom(let transform):
        return transform(input)
    }
}

static func == (lhs: ValidationRule, rhs: ValidationRule) -> Bool {
    switch (lhs, rhs) {
    case (.maxLength(let l), .maxLength(let r)): return l == r
    case (.minLength(let l), .minLength(let r)): return l == r
    case (.noLeadingWhitespace, .noLeadingWhitespace): return true
    case (.noTrailingWhitespace, .noTrailingWhitespace): return true
    case (.noWhitespace, .noWhitespace): return true
    case (.alphanumericOnly, .alphanumericOnly): return true
    case (.numericOnly, .numericOnly): return true
    case (.allowedCharacters(let l), .allowedCharacters(let r)): return l == r
    case (.blockedCharacters(let l), .blockedCharacters(let r)): return l == r
    case (.custom, .custom): return true // Can't compare closures
    default: return false
    }
}
}

// MARK: - Validation State

/// Represents the validation state of an input field.
enum ValidationState: Equatable {
/// Input is valid.
case valid

/// Input is invalid with an associated error message.
case invalid(String)

/// Input has not been validated yet (initial state).
case pending

var isValid: Bool {
    if case .valid = self { return true }
    return false
}

var errorMessage: String? {
    if case .invalid(let message) = self { return message }
    return nil
}
}

// MARK: - Validation Constants

private enum ValidationConstants {
    /// Default debounce interval for validation state updates (in seconds).
    static let debounceInterval: Double = 0.15
}

// MARK: - Validated Text Field Modifier

/// A view modifier that applies validation rules to a text binding.
///
/// Transformations (like maxLength, noWhitespace) are applied immediately.
/// Validation state updates are debounced to improve performance during rapid typing.
struct ValidatedTextFieldModifier: ViewModifier {
@Binding var text: String
let rules: [ValidationRule]
let debounceInterval: Double
let onValidationChange: ((ValidationState) -> Void)?

@State private var validationState: ValidationState = .pending
@State private var debounceTask: Task<Void, Never>?

func body(content: Content) -> some View {
    content
        .onChange(of: text) { _, newValue in
            // Apply transformations immediately (these affect user input)
            let validated = applyRules(to: newValue)
            if validated != newValue {
                text = validated
            }

            // Debounce validation state updates
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .seconds(debounceInterval))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    updateValidationState(for: validated)
                }
            }
        }
        .onAppear {
            updateValidationState(for: text)
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
        }
}

private func applyRules(to input: String) -> String {
    rules.reduce(input) { result, rule in
        rule.apply(to: result)
    }
}

private func updateValidationState(for input: String) {
    // Check min length rule
    for rule in rules {
        if case .minLength(let min) = rule, input.count < min {
            let newState = ValidationState.invalid("Minimum \(min) characters required")
            if validationState != newState {
                validationState = newState
                onValidationChange?(newState)
            }
            return
        }
    }

    if validationState != .valid {
        validationState = .valid
        onValidationChange?(.valid)
    }
}
}

// MARK: - View Extension

extension View {
/// Applies validation rules to a text field binding.
///
/// This modifier transforms input in real-time based on the provided rules.
/// Rules are applied in order, so place more restrictive rules first.
/// Validation state updates are debounced to improve performance during rapid typing.
///
/// - Parameters:
///   - text: The binding to validate.
///   - rules: An array of validation rules to apply.
///   - debounceInterval: Time in seconds to wait before updating validation state (default 0.15s).
///   - onValidationChange: Optional callback when validation state changes.
/// - Returns: A modified view with validation applied.
///
/// ## Example
/// ```swift
/// TextField("Username", text: $username)
///     .validated(
///         text: $username,
///         rules: [.maxLength(20), .alphanumericOnly, .noLeadingWhitespace]
///     )
/// ```
func validated(
    text: Binding<String>,
    rules: [ValidationRule],
    debounceInterval: Double = ValidationConstants.debounceInterval,
    onValidationChange: ((ValidationState) -> Void)? = nil
) -> some View {
    self.modifier(ValidatedTextFieldModifier(
        text: text,
        rules: rules,
        debounceInterval: debounceInterval,
        onValidationChange: onValidationChange
    ))
}
}

// MARK: - Preset Validation Rule Sets

/// Preset validation rule combinations for common use cases.
enum ValidationPresets {

/// Rules for team names: max 50 chars, no leading/trailing whitespace.
static let teamName: [ValidationRule] = [
    .maxLength(50),
    .noLeadingWhitespace
]

/// Rules for round names: max 100 chars, no leading whitespace.
static let roundName: [ValidationRule] = [
    .maxLength(100),
    .noLeadingWhitespace
]

/// Rules for question text: max 500 chars.
static let questionText: [ValidationRule] = [
    .maxLength(500)
]

/// Rules for answer text: max 200 chars.
static let answerText: [ValidationRule] = [
    .maxLength(200)
]

/// Rules for crossword answers: max 12 chars, no whitespace, uppercase.
static let crosswordAnswer: [ValidationRule] = [
    .maxLength(TriviaSchemaConstants.crosswordMaxLetters),
    .noWhitespace,
    .custom { $0.uppercased() }
]

/// Rules for music title: max 100 chars.
static let musicTitle: [ValidationRule] = [
    .maxLength(100)
]

/// Rules for artist name: max 100 chars.
static let artistName: [ValidationRule] = [
    .maxLength(100)
]

/// Rules for Spotify URL: max 200 chars, no whitespace.
static let spotifyURL: [ValidationRule] = [
    .maxLength(200),
    .noWhitespace
]

/// Rules for time input (MM:SS or seconds): max 10 chars, specific characters only.
static let timeInput: [ValidationRule] = [
    .maxLength(10),
    .allowedCharacters(CharacterSet(charactersIn: "0123456789:"))
]
}
