import Foundation
import Testing
@testable import QuickGPT

private func url(_ s: String) -> URL { URL(string: s)! }

/// Protects: only ChatGPT, its CDNs and sign-in providers load inside the panel (it has no address bar,
/// so a look-alike site loaded there is indistinguishable from ChatGPT).
/// Fails when: the dot-boundary or lowercasing in host matching is loosened (e.g. to `hasSuffix`/`contains`).
@Suite struct InAppHostTests {
    @Test(arguments: [
        "https://chatgpt.com/c/1", "https://CHATGPT.COM/", "https://cdn.oaistatic.com/x.js",
        "https://files.oaiusercontent.com/f", "https://accounts.google.com/o/oauth2", "https://auth.openai.com/log-in",
    ])
    func allowed(_ s: String) { #expect(ChatGPT.isInApp(url(s))) }

    @Test(arguments: [
        "https://evilchatgpt.com/", "https://chatgpt.com.evil.com/", "https://chatgpt.com@evil.com/",
        "https://notchatgpt.com/", "https://help.openai.com/", "https://openai.com/policies",
        "about:blank", "mailto:a@chatgpt.com",
    ])
    func rejected(_ s: String) { #expect(!ChatGPT.isInApp(url(s))) }

    @Test func chatGPTHostUsesSameBoundary() {
        #expect(ChatGPT.isChatGPTHost(url("https://chatgpt.com/")))
        #expect(ChatGPT.isChatGPTHost(url("https://ab.CHATGPT.com/")))
        #expect(!ChatGPT.isChatGPTHost(url("https://evilchatgpt.com/")))
        #expect(!ChatGPT.isChatGPTHost(nil))
    }
}

/// Protects: back/forward skips one-time sign-in pages ("sign-in session is no longer valid") but never real chats.
/// Fails when: path/host rules widen (a chat URL counts as auth, so Back breaks) or narrow (the stale page returns).
@Suite struct AuthPageTests {
    @Test(arguments: [
        "https://auth.openai.com/log-in", "https://chatgpt.com/auth/login", "https://chatgpt.com/auth",
        "https://CHATGPT.com/api/auth/session", "https://accounts.google.com/x", "about:blank",
    ])
    func authPages(_ s: String) { #expect(ChatGPT.isAuthPage(url(s))) }

    @Test(arguments: [
        "https://chatgpt.com/", "https://chatgpt.com/c/abc", "https://chatgpt.com/g/g-1-author-helper",
        "https://chatgpt.com/authors", "https://help.openai.com/auth",
    ])
    func realPages(_ s: String) { #expect(!ChatGPT.isAuthPage(url(s))) }
}

/// Protects: file: never opens; nothing opens outside the app without a user click; sign-in redirects stay in-app.
/// Fails when: a condition in NavigationPolicy.decide is dropped or reordered.
@Suite struct NavigationPolicyTests {
    @Test(arguments: [
        // url, isLinkClick, isMainFrame, expected
        ("file:///Applications/Calculator.app", true, true, LinkDecision.cancel),
        ("file:///Applications/Calculator.app", false, true, .cancel),
        ("mailto:a@b.com", true, true, .openExternally),
        ("mailto:a@b.com", false, true, .cancel),
        ("smb://server/share", false, false, .cancel),
        ("https://example.com", true, true, .openExternally),
        ("https://example.com", false, true, .allow),          // redirect, e.g. a sign-in hop
        ("https://example.com", true, false, .allow),          // link inside an iframe stays in that frame
        ("https://chatgpt.com/c/1", true, true, .allow),
        ("https://accounts.google.com/signin", true, true, .allow),
        ("blob:https://chatgpt.com/abc", false, true, .allow),
        ("about:blank", false, true, .allow),
    ])
    func decide(_ s: String, _ click: Bool, _ main: Bool, _ expected: LinkDecision) {
        #expect(NavigationPolicy.decide(url: url(s), isLinkClick: click, isMainFrame: main) == expected)
    }
}

/// Protects: cancelled loads and loads that became downloads don't replace the chat with an error page.
/// Fails when: WebKit 102 (frame load interrupted) stops being ignored, so every download shows "Couldn't load".
@Suite struct LoadFailureTests {
    @Test func classification() {
        #expect(LoadFailure.classify(domain: NSURLErrorDomain, code: NSURLErrorCancelled) == .ignore)
        #expect(LoadFailure.classify(domain: "WebKitErrorDomain", code: 102) == .ignore)
        #expect(LoadFailure.classify(domain: "WebKitErrorDomain", code: 204) == .ignore)
        #expect(LoadFailure.classify(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet) == .offline)
        #expect(LoadFailure.classify(domain: NSURLErrorDomain, code: NSURLErrorTimedOut) == .offline)
        #expect(LoadFailure.classify(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse) == .failed)
        #expect(LoadFailure.classify(domain: "WebKitErrorDomain", code: 101) == .failed)
    }
}

/// Protects: downloads never overwrite an existing file and never land outside the Downloads folder.
/// Fails when: the numbering, extension handling or last-path-component containment regresses.
@Suite struct DownloadNameTests {
    let dir = URL(fileURLWithPath: "/tmp/dl")
    let taken: Set<String> = ["/tmp/dl/a.png", "/tmp/dl/a (1).png", "/tmp/dl/notes"]

    func name(_ n: String) -> String {
        Downloads.uniqueURL(for: n, in: dir, exists: { taken.contains($0.path) }).path
    }

    @Test func numbering() {
        #expect(name("b.png") == "/tmp/dl/b.png")
        #expect(name("a.png") == "/tmp/dl/a (2).png")
        #expect(name("notes") == "/tmp/dl/notes (1)")
        #expect(name("") == "/tmp/dl/download")
        #expect(name("..") == "/tmp/dl/download")
    }

    @Test func staysInsideFolder() {
        for n in ["../../.zshrc", "a/b.txt", "/etc/passwd"] {
            #expect(URL(fileURLWithPath: name(n)).standardized.deletingLastPathComponent().path == "/tmp/dl", "\(n)")
        }
    }
}

/// Protects: a corrupt or hand-edited zoom preference can't make the page unreadable at launch.
@Suite struct ZoomTests {
    @Test func clamp() {
        #expect(Zoom.clamp(1.0) == 1.0)
        #expect(Zoom.clamp(0) == Zoom.range.lowerBound)
        #expect(Zoom.clamp(50) == Zoom.range.upperBound)
        #expect(Zoom.clamp(.nan) == 1.0)
    }
}
