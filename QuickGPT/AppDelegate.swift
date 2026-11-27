import AppKit
import SwiftUI
import KeyboardShortcuts
import Defaults

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var web: WebViewController!
    private var settingsWindow: NSWindow?

    private var clickOutsideMonitor: Any?
    private var keyMonitor: Any?
    /// The app that was frontmost before the panel opened, so focus goes back to it on dismiss.
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        web = WebViewController()
        web.onEscape = { [weak self] in self?.hidePanel(restoreFocus: true) }
        panel = FloatingPanel(controller: web) { [weak self] in self?.hidePanel(restoreFocus: true) }

        setupMenuBar()
        setupGlobalShortcut()
        setupKeyMonitor()
        setupObservers()

        // Preload so the first open is instant.
        web.loadHome()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "QuickGPT") {
            image.isTemplate = true
            button.image = image
        }
        button.action = #selector(menuBarClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(item("New Chat", #selector(newChat), "n"))
        menu.addItem(item("Reload", #selector(reloadChat), "r"))
        menu.addItem(item("Open in Browser", #selector(openInBrowser), ""))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit QuickGPT", #selector(quit), "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func newChat() { showPanel(); web.newChat() }
    @objc private func reloadChat() { web.reload() }
    @objc private func openInBrowser() { web.openCurrentPageInBrowser() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Hosted in our own window: `showSettingsWindow:` no longer opens SwiftUI's Settings scene on macOS 14+.
    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "QuickGPT Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        hidePanel(restoreFocus: false)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel

    private func togglePanel() {
        // A pinned panel that lost focus should come forward, not disappear. (Not gated on NSApp.isActive:
        // clicking a nonactivating panel makes it key without activating us, and one press should still close it.)
        if panel.isVisible && panel.isKeyWindow {
            hidePanel(restoreFocus: true)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        if let front = NSWorkspace.shared.frontmostApplication, front != .current {
            previousApp = front
        }
        if !panel.isVisible { positionPanel() }
        web.recoverIfNeeded()

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        web.focusPrompt()
        startClickOutsideMonitor()
    }

    private func hidePanel(restoreFocus: Bool) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        stopClickOutsideMonitor()

        let otherWindowOpen = NSApp.windows.contains { $0 !== panel && $0.isVisible && $0.styleMask.contains(.titled) }
        // If we're not the active app (e.g. a pinned panel clicked without activating us), the user's
        // current app already has focus; activating the stale previousApp would yank them elsewhere.
        if restoreFocus, NSApp.isActive, !otherWindowOpen, let app = previousApp, !app.isTerminated {
            app.activate(options: [])
        }
        previousApp = nil
    }

    /// Drops the panel under the menu bar icon, or at the top-centre of the active screen when the
    /// icon is hidden (e.g. by the menu bar overflow or macOS menu bar settings).
    private func positionPanel() {
        var size = panel.frame.size
        var anchor: NSRect?
        var screen: NSScreen?

        if let button = statusItem.button, let buttonWindow = button.window, let s = buttonWindow.screen {
            let rect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if s.frame.intersects(rect) {
                anchor = rect
                screen = s
            }
        }
        if screen == nil {
            let mouse = NSEvent.mouseLocation
            screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        }
        guard let visible = screen?.visibleFrame else { return }

        let margin: CGFloat = 8
        if size.height > visible.height - margin * 2 || size.width > visible.width - margin * 2 {
            size = NSSize(width: min(size.width, visible.width - margin * 2),
                          height: min(size.height, visible.height - margin * 2))
            panel.setContentSize(size)
        }

        let midX = anchor?.midX ?? visible.midX
        let top = anchor.map { $0.minY - 4 } ?? (visible.maxY - margin)
        let x = min(max(midX - size.width / 2, visible.minX + margin), visible.maxX - size.width - margin)
        let y = max(top - size.height, visible.minY + margin)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Monitors

    /// Only listens while the panel is on screen, so there's no system-wide hook running in the background.
    /// Decides on mouse-*up*: a press in Finder that turns into dragging a file onto the panel must not hide it.
    private func startClickOutsideMonitor() {
        guard clickOutsideMonitor == nil else { return }
        // Global monitors only see events for other apps, so clicks on our own panel and icon never land here.
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] _ in
            guard let self, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.autoHide()
        }
    }

    /// System prompts that briefly take focus (permission dialogs, password sheets) shouldn't close the panel.
    private static let systemAgents: Set<String> = [
        "com.apple.UserNotificationCenter", "com.apple.SecurityAgent", "com.apple.coreservices.uiagent",
        "com.apple.LocalAuthentication.UIAgent", "com.apple.AuthenticationServicesCore.AuthenticationServicesAgent",
    ]

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    private func autoHide() {
        guard panel.isVisible, !Defaults[.keepPanelOpen], panel.attachedSheet == nil else { return }
        hidePanel(restoreFocus: false)
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
            let key = event.charactersIgnoringModifiers ?? ""

            if flags == .command && key == ",", self.panel.attachedSheet == nil {
                self.openSettings()
                return nil
            }
            guard event.window === self.panel, self.panel.attachedSheet == nil else { return event }

            switch (flags, key) {
            case (.command, "n"): self.web.newChat()
            case (.command, "r"): self.web.reload()
            case (.command, "w"): self.hidePanel(restoreFocus: true)
            case (.command, "="), (.command, "+"), ([.command, .shift], "+"): self.web.zoom(by: 0.1)
            case (.command, "-"): self.web.zoom(by: -0.1)
            case (.command, "0"): self.web.resetZoom()
            default: return event
            }
            return nil
        }
    }

    private func setupObservers() {
        let center = NotificationCenter.default
        // Cmd-Tab away: behave like clicking away. If a mouse button is down, this is a click in another app
        // and the mouse-up monitor decides instead (so dragging a file in from Finder keeps the panel open).
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard NSEvent.pressedMouseButtons == 0 else { return }
            if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, Self.systemAgents.contains(id) { return }
            self?.autoHide()
        }
        center.addObserver(forName: .quickGPTSessionCleared, object: nil, queue: .main) { [weak self] _ in
            self?.web.loadHome()
        }
    }

    // MARK: - Global Shortcut

    private func setupGlobalShortcut() {
        // One-time move from the old default (⌘⇧Space) to ⌥X. Custom shortcuts are left alone.
        if !Defaults[.didMigrateShortcut] {
            Defaults[.didMigrateShortcut] = true
            if KeyboardShortcuts.getShortcut(for: .toggleQuickGPT) == .init(.space, modifiers: [.command, .shift]) {
                KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.option]), for: .toggleQuickGPT)
            }
        }
        // Key-down rather than key-up so the panel appears the instant the shortcut is pressed.
        KeyboardShortcuts.onKeyDown(for: .toggleQuickGPT) { [weak self] in
            self?.togglePanel()
        }
    }
}
