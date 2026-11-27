import Foundation

// Pure decision logic, kept free of WebKit/AppKit so it can be unit tested (see Tests/QuickGPTTests).

enum ChatGPT {
    static let home = URL(string: "https://chatgpt.com")!

    /// Sign-in providers. Pages on these hosts carry one-time tokens.
    static let authHosts = [
        "auth.openai.com", "auth0.openai.com",
        "accounts.google.com", "appleid.apple.com", "idmsa.apple.com",
        "login.microsoftonline.com", "login.live.com", "account.live.com",
        "challenges.cloudflare.com",
    ]

    /// Hosts whose *clicked* links stay inside the panel; every other clicked link opens in the default browser.
    /// Redirects never go through this list, so sign-in still completes even if it hops through other hosts.
    static let inAppHosts = ["chatgpt.com", "oaistatic.com", "oaiusercontent.com"] + authHosts

    /// `host` is `domain` or a subdomain of it. Requires a dot boundary, so `evilchatgpt.com` doesn't match.
    static func host(_ host: String, isWithin domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    static func isChatGPTHost(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return Self.host(host, isWithin: "chatgpt.com")
    }

    static func isInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return inAppHosts.contains { Self.host(host, isWithin: $0) }
    }

    /// Sign-in pages carry one-time tokens; revisiting them from history shows
    /// "Your sign-in session is no longer valid", so back/forward skips them.
    /// Pages with no host (about:blank, the offline error page) count too: there's nothing to go back to there.
    static func isAuthPage(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        if authHosts.contains(where: { Self.host(host, isWithin: $0) }) { return true }
        guard Self.host(host, isWithin: "chatgpt.com") else { return false }
        let path = url.path.lowercased()
        return ["/auth", "/api/auth"].contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

enum LinkDecision: Equatable {
    case allow, cancel, openExternally
}

enum NavigationPolicy {
    private static let webSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript"]

    /// - Parameters:
    ///   - isLinkClick: the user clicked a link (`WKNavigationType.linkActivated`), as opposed to a redirect or script.
    ///   - isMainFrame: the navigation targets the top-level page (a new-window target counts as main frame).
    static func decide(url: URL, isLinkClick: Bool, isMainFrame: Bool) -> LinkDecision {
        let scheme = url.scheme?.lowercased() ?? ""
        if !webSchemes.contains(scheme) {
            // mailto:, tel:, app links: hand off only when the user clicked them. Never open file: URLs,
            // which would let any page or iframe launch local apps and files.
            return isLinkClick && scheme != "file" ? .openExternally : .cancel
        }
        // Clicked links to other sites open in the browser so the chat stays put.
        if isLinkClick, isMainFrame, scheme == "http" || scheme == "https", !ChatGPT.isInApp(url) {
            return .openExternally
        }
        return .allow
    }
}

enum LoadFailure: Equatable {
    case ignore, offline, failed

    /// WebKitErrorFrameLoadInterruptedByPolicyChange: the load became a download.
    private static let frameLoadInterrupted = 102
    /// WebKitErrorPlugInWillHandleLoad.
    private static let pluginHandledLoad = 204
    private static let offlineCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
        NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
    ]

    static func classify(domain: String, code: Int) -> LoadFailure {
        if domain == NSURLErrorDomain && code == NSURLErrorCancelled { return .ignore }
        if domain == "WebKitErrorDomain" && (code == frameLoadInterrupted || code == pluginHandledLoad) { return .ignore }
        return domain == NSURLErrorDomain && offlineCodes.contains(code) ? .offline : .failed
    }
}

enum Downloads {
    /// A destination in `dir` that doesn't overwrite anything: "a.png", then "a (1).png", "a (2).png"…
    /// Only the last path component of `filename` is used, so a name like "../x" can't escape `dir`.
    static func uniqueURL(for filename: String, in dir: URL,
                          exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        var name = (filename as NSString).lastPathComponent
        if name.isEmpty || name == "." || name == ".." || name == "/" { name = "download" }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var url = dir.appendingPathComponent(name)
        var i = 1
        while exists(url) {
            url = dir.appendingPathComponent(ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)")
            i += 1
        }
        return url
    }
}

enum Zoom {
    static let range = 0.5...2.0
    static let step = 0.1

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
