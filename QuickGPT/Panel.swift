import AppKit
import SwiftUI
import WebKit
import Defaults

// MARK: - Floating Panel

final class FloatingPanel: NSPanel {
    var onClose: (() -> Void)?
    private weak var webView: WKWebView?

    static let minSize = NSSize(width: 360, height: 420)

    init(controller: WebViewController, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.webView = controller.webView

        let size = NSSize(width: max(Defaults[.panelWidth], Self.minSize.width),
                          height: max(Defaults[.panelHeight], Self.minSize.height))
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        let hosting = NSHostingView(rootView: PanelView(controller: controller, state: controller.state))
        hosting.sizingOptions = [.minSize]
        contentView = hosting

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = true
        hasShadow = true
        animationBehavior = .utilityWindow
        minSize = Self.minSize
        isReleasedWhenClosed = false
        // NSPanel defaults this to true, which hides the panel whenever another app is clicked:
        // that silently broke pinning and left a "ghost" panel that reappeared on the next activation.
        // Hiding is decided by AppDelegate instead.
        hidesOnDeactivate = false

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 12
        contentView?.layer?.masksToBounds = true

        NotificationCenter.default.addObserver(self, selector: #selector(didEndLiveResize),
                                               name: NSWindow.didEndLiveResizeNotification, object: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Escape inside the page is handled by the injected script, which knows whether a ChatGPT
    /// menu or dialog needs it first. Only close here when focus is outside the web view.
    override func cancelOperation(_ sender: Any?) {
        if let webView, let responder = firstResponder as? NSView,
           responder === webView || responder.isDescendant(of: webView), !webView.isLoading {
            return
        }
        onClose?()
    }

    @objc private func didEndLiveResize() {
        Defaults[.panelWidth] = frame.width
        Defaults[.panelHeight] = frame.height
    }
}

// MARK: - Panel View

struct PanelView: View {
    let controller: WebViewController
    @ObservedObject var state: WebViewState
    @Default(.keepPanelOpen) private var keepOpen

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            WebViewWrapper(webView: controller.webView)
        }
        .frame(minWidth: FloatingPanel.minSize.width, minHeight: FloatingPanel.minSize.height)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(spacing: 12) {
            HeaderButton(symbol: "chevron.left", help: "Back (⌘[)", action: controller.goBack)
                .disabled(!state.canGoBack)
                .opacity(state.canGoBack ? 1 : 0.35)

            Text("QuickGPT")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            HeaderButton(symbol: keepOpen ? "pin.fill" : "pin",
                         help: keepOpen ? "Unpin (auto-hide when clicking away)" : "Pin (stay open when clicking away)",
                         isActive: keepOpen) {
                keepOpen.toggle()
            }

            HeaderButton(symbol: "square.and.pencil", help: "New Chat (⌘N)", action: controller.newChat)
            HeaderButton(symbol: "arrow.clockwise", help: "Reload (⌘R)", action: controller.reload)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) {
            if state.isLoading {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * max(state.progress, 0.08), height: 2)
                        .animation(.easeOut(duration: 0.2), value: state.progress)
                }
                .frame(height: 2)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: state.isLoading)
    }
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        .help(help)
    }
}

struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
