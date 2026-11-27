import AppKit
import SwiftUI
import WebKit
import KeyboardShortcuts
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var webView: WKWebView!
    private var webViewDelegate: WebViewDelegate!
    private var clickOutsideMonitor: Any?
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupWebView()
        setupPanel()
        setupMenuBar()
        setupGlobalShortcut()
        setupMonitors()
        preloadChatGPT()
    }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.suppressesIncrementalRendering = false

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true

        // Set up delegate to handle Google sign-in and popups
        webViewDelegate = WebViewDelegate(webView: webView)
        webView.navigationDelegate = webViewDelegate
        webView.uiDelegate = webViewDelegate
    }

    private func preloadChatGPT() {
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = FloatingPanel(webView: webView)
        panel.onClose = { [weak self] in
            self?.hidePanel()
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "QuickGPT") {
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(menuBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Reload", action: #selector(reloadChat), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit QuickGPT", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func reloadChat() { webView.reload() }

    @objc private func newChat() {
        if let url = URL(string: "https://chatgpt.com") {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Panel Toggle

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = panel.frame.size

        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePanel() {
        panel.orderOut(nil)
    }

    // MARK: - Event Monitors

    private func setupMonitors() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            let mouseLocation = NSEvent.mouseLocation
            let panelFrame = self.panel.frame

            if !panelFrame.contains(mouseLocation) {
                if let buttonWindow = self.statusItem.button?.window {
                    if !buttonWindow.frame.contains(mouseLocation) {
                        self.hidePanel()
                    }
                } else {
                    self.hidePanel()
                }
            }
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 && self.panel.isVisible {
                self.hidePanel()
                return nil
            }
            return event
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

// MARK: - WebView Delegate (Handles Google Sign-in & Popups)

class WebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    private weak var mainWebView: WKWebView?

    init(webView: WKWebView) {
        self.mainWebView = webView
        super.init()
    }

    // Handle popup windows (Google sign-in opens in popup)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Load popup URL in main webview instead of opening new window
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // Allow all navigations (including Google OAuth)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    // Handle navigation response
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
    var onClose: (() -> Void)?

    init(webView: WKWebView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 650),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        let contentView = NSHostingView(rootView: PanelView(webView: webView, onNewChat: {
            if let url = URL(string: "https://chatgpt.com") {
                webView.load(URLRequest(url: url))
            }
        }, onReload: {
            webView.reload()
        }, onBack: {
            if webView.canGoBack {
                webView.goBack()
            }
        }))

        self.contentView = contentView
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.hasShadow = true

        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 12
        self.contentView?.layer?.masksToBounds = true
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }
}

// MARK: - Panel View

struct PanelView: View {
    let webView: WKWebView
    let onNewChat: () -> Void
    let onReload: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Back")

                Text("QuickGPT")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button(action: onNewChat) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("New Chat")

                Button(action: onReload) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reload")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            WebViewWrapper(webView: webView)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

extension Defaults.Keys {
    static let inlineModeEnabled = Key<Bool>("inlineModeEnabled", default: true)
}
