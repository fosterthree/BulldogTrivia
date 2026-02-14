import AppKit

// AppDelegate for SwiftUI DocumentGroup apps.
// Note: SwiftUI's DocumentGroup uses modern autosave behavior (like Pages, Numbers, Keynote).
// Documents save automatically - no traditional "Do you want to save?" dialogs.
// This prevents data loss and matches Apple's modern document architecture.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        removeEventMonitor()
        FocusManager.shared.start()

        // Install global keyboard event monitor for arrow keys
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle arrow keys
            guard event.keyCode == 123 || event.keyCode == 124 else {
                return event  // Not an arrow key, pass through
            }

            // Check if a text field or text view is focused
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSText || firstResponder is NSTextView {
                return event  // Text editing active, pass through
            }

            // Get the active presentation controller
            guard let controller = PresentationControllerManager.shared.activeController else {
                return event  // No controller, pass through
            }

            // Handle arrow keys
            switch event.keyCode {
            case 123:  // Left arrow
                if controller.canGoPrevious {
                    controller.previous()
                    return nil  // Consume the event
                }
            case 124:  // Right arrow
                if controller.canGoNext {
                    controller.next()
                    return nil  // Consume the event
                }
            default:
                break
            }

            return event  // Pass through if not handled
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEventMonitor()
        FocusManager.shared.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // DocumentGroup autosaves continuously. On some iCloud-backed files,
        // AppKit can hang during final coordinated terminate-save.
        // Clear pending edited state so termination does not block on that pass.
        for document in NSDocumentController.shared.documents {
            document.updateChangeCount(.changeCleared)
        }
        return .terminateNow
    }

    deinit {
        removeEventMonitor()
        FocusManager.shared.stop()
    }

    private func removeEventMonitor() {
        guard let monitor = eventMonitor else { return }
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
    }
}
