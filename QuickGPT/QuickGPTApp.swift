import SwiftUI
import KeyboardShortcuts

@main
struct QuickGPTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

extension KeyboardShortcuts.Name {
    static let toggleQuickGPT = Self("toggleQuickGPT")
}
