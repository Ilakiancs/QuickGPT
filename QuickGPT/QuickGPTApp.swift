import SwiftUI
import KeyboardShortcuts
import Defaults

@main
struct QuickGPTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // SwiftUI needs a scene; the real settings window is opened by AppDelegate.
        Settings { EmptyView() }
    }
}

extension KeyboardShortcuts.Name {
    static let toggleQuickGPT = Self("toggleQuickGPT", default: .init(.x, modifiers: [.option]))
}

extension Defaults.Keys {
    static let keepPanelOpen = Key<Bool>("keepPanelOpen", default: false)
    static let panelWidth = Key<Double>("panelWidth", default: 420)
    static let panelHeight = Key<Double>("panelHeight", default: 650)
    static let pageZoom = Key<Double>("pageZoom", default: 1.0)
    static let didMigrateShortcut = Key<Bool>("didMigrateShortcutToOptionX", default: false)
}

extension Notification.Name {
    static let quickGPTSessionCleared = Notification.Name("QuickGPTSessionCleared")
}
