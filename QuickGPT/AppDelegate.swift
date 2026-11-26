import AppKit
import SwiftUI
import WebKit
import KeyboardShortcuts
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var webView: WKWebView!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only - no dock icon
        NSApp.setActivationPolicy(.accessory)

        setupWebView()
        setupPanel()
        setupMenuBar()
        setupGlobalShortcut()
        setupClickOutsideMonitor()

        // Preload ChatGPT for instant access
        preloadChatGPT()
    }

    // MARK: - WebView (Persistent, Shared Instance)

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Performance optimizations
        config.suppressesIncrementalRendering = false

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
    }

    private func preloadChatGPT() {
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Panel (MacGPT-style dropdown)

    private func setupPanel() {
        let contentView = NSHostingView(rootView: PanelContentView(webView: webView, onClose: { [weak self] in
            self?.hidePanel()
        }))

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 650),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.invalidateShadow()

        // Round corners
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "QuickGPT")
            button.image?.isTemplate = true
            button.action = #selector(menuBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Reload", action: #selector(reloadChat), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickGPT", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func reloadChat() {
        webView.reload()
    }

    @objc private func newChat() {
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Panel Toggle

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }

        // Position below menu bar icon
        let buttonRect = button.window!.convertToScreen(button.convert(button.bounds, to: nil))
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        let x = buttonRect.midX - panelWidth / 2
        let y = buttonRect.minY - panelHeight - 5

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)

        // Activate for keyboard focus
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePanel() {
        panel.orderOut(nil)
    }

    // MARK: - Click Outside to Close

    private func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            // Check if click is outside panel and menu bar button
            let clickLocation = event.locationInWindow
            if let clickWindow = event.window {
                let screenPoint = clickWindow.convertToScreen(NSRect(origin: clickLocation, size: .zero)).origin

                if !self.panel.frame.contains(screenPoint) {
                    if let buttonFrame = self.statusItem.button?.window?.frame {
                        if !buttonFrame.contains(screenPoint) {
                            self.hidePanel()
                        }
                    }
                }
            } else {
                // Click outside any window
                self.hidePanel()
            }
        }
    }

    // MARK: - Global Shortcut

    private func setupGlobalShortcut() {
        if KeyboardShortcuts.getShortcut(for: .toggleQuickGPT) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: [.command, .shift]), for: .toggleQuickGPT)
        }

        KeyboardShortcuts.onKeyUp(for: .toggleQuickGPT) { [weak self] in
            self?.togglePanel()
        }
    }
}

// MARK: - Panel Content View

struct PanelContentView: View {
    let webView: WKWebView
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("QuickGPT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {
                    if let url = URL(string: "https://chatgpt.com") {
                        webView.load(URLRequest(url: url))
                    }
                }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("New Chat")

                Button(action: { webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reload")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // WebView
            WebViewWrapper(webView: webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.background)
        .frame(width: 420, height: 650)
    }
}

// MARK: - WebView Wrapper

struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let inlineModeEnabled = Key<Bool>("inlineModeEnabled", default: true)
}
