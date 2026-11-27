import AppKit
import WebKit
import Defaults

extension ChatGPT {
    static func backTarget(in webView: WKWebView) -> WKBackForwardListItem? {
        webView.backForwardList.backList.last { !isAuthPage($0.url) }
    }

    static func forwardTarget(in webView: WKWebView) -> WKBackForwardListItem? {
        webView.backForwardList.forwardList.first { !isAuthPage($0.url) }
    }
}

/// Loading state the SwiftUI header observes.
final class WebViewState: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var canGoBack = false
    private var observations: [NSKeyValueObservation] = []

    init(webView: WKWebView) {
        observations = [
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] wv, _ in
                self?.isLoading = wv.isLoading
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                // Avoid re-rendering SwiftUI for tiny progress ticks.
                guard let self, abs(wv.estimatedProgress - self.progress) >= 0.05 || wv.estimatedProgress >= 1 else { return }
                self.progress = wv.estimatedProgress
            },
            // Back is enabled only if there's a non-sign-in page to return to. In-app navigation
            // changes `url` without necessarily changing `canGoBack`, so watch both.
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                self?.updateCanGoBack(wv)
            },
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                self?.updateCanGoBack(wv)
            },
        ]
    }

    private func updateCanGoBack(_ webView: WKWebView) {
        let value = ChatGPT.backTarget(in: webView) != nil
        if value != canGoBack { canGoBack = value }
    }
}

final class WebViewController: NSObject {
    let webView: WKWebView
    let state: WebViewState

    /// Called when the page asks to dismiss the panel (Escape pressed with nothing open on the page).
    var onEscape: (() -> Void)?

    private var downloadDestinations: [ObjectIdentifier: URL] = [:]
    private var lastCrash: Date?
    /// A second crash within this window shows the error page instead of reloading in a loop.
    private static let crashLoopWindow: TimeInterval = 10

    /// Nothing loaded yet, or showing the offline/error page (loaded from a string, so it has an about: URL).
    /// Derived from the URL rather than a flag: the error page's own load would reset a flag set before it.
    private var needsRecovery: Bool {
        guard let url = webView.url else { return true }
        return url.scheme == "about"
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // Popups only from user clicks, so pages can't spam the default browser.
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        // Append a real Safari token to WebKit's own UA so Google sign-in accepts the embedded view,
        // while keeping the WebKit version accurate for the installed OS.
        config.applicationNameForUserAgent = "Version/\(Self.safariVersion) Safari/605.1.15"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.pageZoom = CGFloat(Zoom.clamp(Defaults[.pageZoom]))
        #if DEBUG
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        #endif

        state = WebViewState(webView: webView)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        let controller = config.userContentController
        controller.addUserScript(WKUserScript(source: Self.pageScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.add(WeakScriptMessageHandler(self), name: "quickgpt")
    }

    // MARK: - Actions

    func loadHome() {
        webView.load(URLRequest(url: ChatGPT.home))
    }

    /// Starts a new chat through ChatGPT's own router (instant) and only falls back to a full load.
    func newChat() {
        guard ChatGPT.isChatGPTHost(webView.url) else { return loadHome() }
        let js = """
        (() => {
          const a = document.querySelector('a[data-testid="create-new-chat-button"], [data-testid="create-new-chat-button"], nav a[href="/"], a[href="/"]');
          if (!a) return false;
          a.click();
          return true;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            if (result as? Bool) != true { self?.loadHome() }
        }
    }

    func reload() {
        if needsRecovery { loadHome() } else { webView.reload() }
    }

    /// Called when the panel opens: retry if the last load failed (e.g. launched at login before Wi-Fi).
    func recoverIfNeeded() {
        if needsRecovery { loadHome() }
    }

    func goBack() {
        if let item = ChatGPT.backTarget(in: webView) { webView.go(to: item) }
    }

    func goForward() {
        if let item = ChatGPT.forwardTarget(in: webView) { webView.go(to: item) }
    }

    func openCurrentPageInBrowser() {
        NSWorkspace.shared.open(webView.url ?? ChatGPT.home)
    }

    /// Puts the caret in the prompt box unless the user is already typing somewhere else on the page.
    func focusPrompt() {
        webView.window?.makeFirstResponder(webView)
        webView.evaluateJavaScript("""
        (() => {
          const a = document.activeElement;
          if (a && a !== document.body && a.closest('input, textarea, [contenteditable="true"]')) return;
          document.querySelector('#prompt-textarea')?.focus({ preventScroll: true });
        })();
        """)
    }

    func zoomIn() { setZoom(Double(webView.pageZoom) + Zoom.step) }
    func zoomOut() { setZoom(Double(webView.pageZoom) - Zoom.step) }
    func resetZoom() {
        webView.magnification = 1 // undo pinch zoom too
        setZoom(1.0)
    }

    private func setZoom(_ value: Double) {
        let clamped = Zoom.clamp(value)
        webView.pageZoom = CGFloat(clamped)
        Defaults[.pageZoom] = clamped
    }

    // MARK: - Helpers

    private static let safariVersion: String = {
        let plist = URL(fileURLWithPath: "/Applications/Safari.app/Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: plist), let version = dict["CFBundleShortVersionString"] as? String {
            return version
        }
        return "18.0"
    }()

    /// Injected into chatgpt.com. Keeps UI chrome (buttons, menus, screen-reader labels) out of
    /// text selections and copies, and tells the app when Escape wasn't used by the page.
    private static let pageScript = #"""
    (() => {
      if (window.__quickgpt) return;
      window.__quickgpt = true;
      const onChatGPT = /(^|\.)chatgpt\.com$/.test(location.hostname);

      const CHROME = 'button, [role="button"], [role="menuitem"], [role="tab"], [role="toolbar"], nav, label, select, svg, .sr-only, #page-header';

      const style = document.createElement('style');
      style.id = 'quickgpt-style';
      style.textContent = CHROME + ' { -webkit-user-select: none !important; user-select: none !important; }';
      const ensureStyle = () => { if (!document.getElementById('quickgpt-style')) (document.head || document.documentElement).appendChild(style); };
      // Selection/copy cleanup is tuned for ChatGPT's markup; leave sign-in pages untouched.
      if (onChatGPT) {
        ensureStyle();
        if (document.head) new MutationObserver(ensureStyle).observe(document.head, { childList: true });
      }

      const isEditable = n => {
        const el = n && (n.nodeType === 1 ? n : n.parentElement);
        return !!(el && el.closest('input, textarea, [contenteditable="true"], [contenteditable=""]'));
      };

      // Some browsers still serialize non-selectable nodes inside a range, so strip them on copy too.
      if (onChatGPT) document.addEventListener('copy', e => {
        const sel = window.getSelection();
        if (!sel || sel.isCollapsed || !sel.rangeCount || isEditable(sel.anchorNode) || isEditable(sel.focusNode)) return;
        const box = document.createElement('div');
        for (let i = 0; i < sel.rangeCount; i++) box.appendChild(sel.getRangeAt(i).cloneContents());
        const junk = box.querySelectorAll(CHROME);
        if (!junk.length) return;
        junk.forEach(n => n.remove());
        box.style.cssText = 'position:fixed;left:-99999px;top:0;';
        document.body.appendChild(box);
        const text = box.innerText.trim();
        const html = box.innerHTML;
        box.remove();
        e.clipboardData.setData('text/plain', text);
        e.clipboardData.setData('text/html', html);
        e.preventDefault();
      }, true);

      // Escape closes the panel only when the page has nothing open to dismiss itself.
      const OVERLAY = '[role="dialog"], [role="menu"], [role="listbox"], [data-radix-popper-content-wrapper]';
      let overlayOpen = false;
      window.addEventListener('keydown', e => {
        // Only count overlays that are actually on screen; ChatGPT can keep hidden ones mounted.
        if (e.key === 'Escape') overlayOpen = [...document.querySelectorAll(OVERLAY)]
          .some(el => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden');
      }, true);
      window.addEventListener('keydown', e => {
        if (e.key !== 'Escape' || e.isComposing || e.defaultPrevented || overlayOpen) return;
        if (e.shiftKey || e.metaKey || e.ctrlKey || e.altKey) return; // Shift+Esc focuses ChatGPT's prompt
        window.webkit?.messageHandlers?.quickgpt?.postMessage({ type: 'escape' });
      });
    })();
    """#
}

// MARK: - Navigation

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            return decisionHandler(.download)
        }
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }

        // Swipe gestures and the page's own history.back() can still land on a stale sign-in page.
        // Cancel and continue to the nearest real page in the same direction instead.
        if navigationAction.navigationType == .backForward,
           navigationAction.targetFrame?.isMainFrame == true,
           ChatGPT.isAuthPage(url),
           let current = webView.url, !ChatGPT.isAuthPage(current) {
            decisionHandler(.cancel)
            let goingBack = webView.backForwardList.backList.contains { $0.url == url }
            DispatchQueue.main.async { [weak self] in
                goingBack ? self?.goBack() : self?.goForward()
            }
            return
        }

        switch NavigationPolicy.decide(url: url,
                                       isLinkClick: navigationAction.navigationType == .linkActivated,
                                       isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true) {
        case .allow:
            decisionHandler(.allow)
        case .cancel:
            decisionHandler(.cancel)
        case .openExternally:
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        // Files sent as attachments (e.g. a generated .png or .txt) must download, not replace the chat.
        // Only the main frame downloads, so hidden iframes can't drop files into ~/Downloads.
        if navigationResponse.isForMainFrame, disposition.hasPrefix("attachment") || !navigationResponse.canShowMIMEType {
            return decisionHandler(.download)
        }
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleLoadFailure(error)
    }

    /// WebKit kills the content process under memory pressure; bring the chat back instead of a blank panel.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let now = Date()
        defer { lastCrash = now }
        if let last = lastCrash, now.timeIntervalSince(last) < Self.crashLoopWindow {
            return showError(title: "ChatGPT stopped unexpectedly", detail: "The page crashed twice in a row.")
        }
        if let url = webView.url, !ChatGPT.isAuthPage(url) { webView.reload() } else { loadHome() }
    }

    private func handleLoadFailure(_ error: Error) {
        let ns = error as NSError
        switch LoadFailure.classify(domain: ns.domain, code: ns.code) {
        case .ignore: return // cancelled, or the load turned into a download
        case .offline: showError(title: "You're offline", detail: ns.localizedDescription)
        case .failed: showError(title: "Couldn't load ChatGPT", detail: ns.localizedDescription)
        }
    }

    /// WKWebView shows nothing on failure, which left a blank white panel. Show a page with a retry link.
    private func showError(title: String, detail: String) {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        let html = """
        <!doctype html><meta charset="utf-8"><meta name="color-scheme" content="light dark">
        <style>
          body { font: 13px -apple-system, sans-serif; display: grid; place-items: center; height: 100vh; margin: 0; text-align: center; color: CanvasText; background: Canvas; }
          h1 { font-size: 15px; font-weight: 600; margin: 0 0 6px; } p { margin: 0 0 16px; opacity: .65; max-width: 280px; }
          a { display: inline-block; padding: 6px 14px; border-radius: 6px; background: AccentColor; color: white; text-decoration: none; }
        </style>
        <div><h1>\(esc(title))</h1><p>\(esc(detail))</p><a href="\(ChatGPT.home.absoluteString)">Try Again</a></div>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - UI (popups, dialogs, file picker)

extension WebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url, url.scheme?.hasPrefix("http") == true else { return nil }
        if ChatGPT.isInApp(url) {
            webView.load(URLRequest(url: url))
        } else {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        present(panel) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        present(alert) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    /// Voice mode isn't supported: refuse mic/camera outright so WebKit never touches the devices
    /// (and the app never needs, or asks for, microphone/camera access).
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }

    private func present(_ panel: NSOpenPanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func present(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }
}

// MARK: - Downloads

extension WebViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let url = Downloads.uniqueURL(for: suggestedFilename, in: downloads)
        downloadDestinations[ObjectIdentifier(download)] = url
        completionHandler(url)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        // Bounces the Downloads stack in the Dock, like Safari does, without stealing focus.
        DistributedNotificationCenter.default().post(name: .init("com.apple.DownloadFileFinished"), object: url.path)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
    }
}

// MARK: - Script messages

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Message handlers are reachable from every frame; only trust the top-level page.
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if type == "escape" { onEscape?() }
    }
}

/// WKUserContentController retains its handlers strongly; this breaks the cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
