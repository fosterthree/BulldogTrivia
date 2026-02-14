//  BulldogTriviaApp.swift
//  BulldogTrivia

//  The App Entry Point.

//  Created by Asa Foster // 2026

import SwiftUI
import AppKit
import Combine

// MARK: - Sidebar Preview State

/// Manages the visibility state of the sidebar preview pane.
/// Uses @AppStorage to persist the preference across app launches.
class SidebarPreviewState: ObservableObject {
    @AppStorage("showSidebarPreview") var isShown = true
}

// MARK: - Focus Manager

/// Global focus manager that dismisses text field focus when clicking outside fields.
/// Installed once at app launch and removed during app termination.
final class FocusManager {
    static let shared = FocusManager()

    private var eventMonitor: Any?

    private init() {}

    func start() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window, let contentView = window.contentView else {
                return event
            }

            let clickedView = contentView.hitTest(event.locationInWindow)
            if let clickedView, FocusManager.isTextInputView(clickedView) {
                return event
            }

            window.makeFirstResponder(nil)
            return event
        }
    }

    func stop() {
        guard let monitor = eventMonitor else { return }
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
    }

    private static func isTextInputView(_ view: NSView) -> Bool {
        var currentView: NSView? = view

        while let candidate = currentView {
            if candidate is NSTextField || candidate is NSTextView || candidate is NSSearchField {
                return true
            }
            currentView = candidate.superview
        }

        return false
    }

    deinit {
        stop()
    }
}

@main
struct BulldogTriviaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var spotifyController = SpotifyController()
    @StateObject private var sidebarPreviewState = SidebarPreviewState()

    var body: some Scene {
        DocumentGroup(newDocument: TriviaDocument()) { file in
            DocumentWindowView(document: file.$document, previewState: sidebarPreviewState)
                .environmentObject(spotifyController)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1600, height: 1200)
        .commands {
            SidebarCommands()
            ViewCommands(previewState: sidebarPreviewState)
        }

        // Presentation Window (for external display)
        Window("Presentation", id: "presentation") {
            PresentationWindowView()
                .environmentObject(spotifyController)
                .configurePresentationWindow()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1920, height: 1080)
        .commandsRemoved()  // Prevents automatic "Presentation" section in Window menu
    }
}

// MARK: - Presentation Controller Manager

/// Singleton that tracks which PresentationController is currently active.
/// This allows the presentation window to find the correct controller.
class PresentationControllerManager: ObservableObject {
    static let shared = PresentationControllerManager()
    private init() {}

    private var _activeController: PresentationController? {
        willSet { objectWillChange.send() }
    }

    var activeController: PresentationController? {
        get { _activeController }
        set { _activeController = newValue }
    }
}

// MARK: - Document Window View

/// Wrapper view that creates a per-document PresentationController instance.
/// This ensures each open document has its own independent presentation state.
struct DocumentWindowView: View {
    @Binding var document: TriviaDocument
    @ObservedObject var previewState: SidebarPreviewState
    @StateObject private var presentationController = PresentationController()
    @State private var isFocused = false

    var body: some View {
        ContentView(document: $document, showSidebarPreview: $previewState.isShown)
            .environmentObject(presentationController)
            .background(WindowFocusDetector(isFocused: $isFocused))
            .background(InitialFocusPreventer())
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // When this window gains focus, set it as the active controller
                    PresentationControllerManager.shared.activeController = presentationController
                }
            }
            .onAppear {
                // Set as active controller on appear
                PresentationControllerManager.shared.activeController = presentationController
            }
    }
}

// MARK: - Initial Focus Preventer

/// Prevents the window from auto-focusing text fields when it first appears.
struct InitialFocusPreventer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        FocusPreventingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class FocusPreventingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = window else { return }

            // Clear initial first responder immediately
            window.initialFirstResponder = nil
            window.makeFirstResponder(nil)

            // Also clear after layout to catch any deferred focus attempts
            DispatchQueue.main.async {
                window.makeFirstResponder(nil)
            }
        }
    }
}

// MARK: - Window Focus Detector

/// Helper view that detects when the window containing this view gains/loses focus.
struct WindowFocusDetector: NSViewRepresentable {
    @Binding var isFocused: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        NotificationCenter.default.removeObserver(context.coordinator)

        // Observe window key status changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )

        return view
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.isActive = false
        NotificationCenter.default.removeObserver(coordinator)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.isFocused = $isFocused
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFocused: $isFocused)
    }

    class Coordinator: NSObject {
        var isFocused: Binding<Bool>
        weak var view: NSView?
        var isActive = true

        init(isFocused: Binding<Bool>) {
            self.isFocused = isFocused
        }

        @objc func windowDidBecomeKey(_ notification: Notification) {
            guard isActive else { return }
            if let notificationWindow = notification.object as? NSWindow,
               let viewWindow = view?.window,
               notificationWindow === viewWindow {
                isFocused.wrappedValue = true
            }
        }

        @objc func windowDidResignKey(_ notification: Notification) {
            guard isActive else { return }
            if let notificationWindow = notification.object as? NSWindow,
               let viewWindow = view?.window,
               notificationWindow === viewWindow {
                isFocused.wrappedValue = false
            }
        }

        deinit {
            isActive = false
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Presentation Window View

struct PresentationWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = PresentationControllerManager.shared

    var body: some View {
        Group {
            if let controller = manager.activeController {
                PresentationView()
                    .environmentObject(controller)
            } else {
                Text("No active presentation")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Keyboard Commands
// Note: Arrow key navigation (→ and ←) is handled by AppDelegate's global event monitor
// This approach avoids the macOS error sound when shortcuts would be disabled

// MARK: - View Commands

struct ViewCommands: Commands {
    @ObservedObject var previewState: SidebarPreviewState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowList) {
            Button {
                openWindow(id: "presentation")
            } label: {
                Label("Open Presentation Window", systemImage: "display")
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button {
                previewState.isShown.toggle()
            } label: {
                Label(previewState.isShown ? "Hide Preview" : "Show Preview", systemImage: "inset.filled.bottomleft.rectangle")
            }
            .keyboardShortcut("0", modifiers: [.command, .shift])  // ⌘⇧0
        }
    }
}
