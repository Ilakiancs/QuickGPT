<div align="center">

# QuickGPT

**Native ChatGPT client for macOS, built in Swift**

[Getting started](#getting-started) · [Development](#development)

</div>

<br>

A lightweight menu bar app that puts ChatGPT one shortcut away. No Electron, no browser tabs, no distractions. Pure Swift and WebKit, optimized for speed.

| | |
|---|---|
| **Platform** | macOS 13.0+ (Ventura and later) |
| **Stack** | Swift 5.9, SwiftUI, WebKit |
| **Binary size** | ~2 MB |
| **Memory** | ~80 MB idle |

---

## Getting started

### Install

```bash
brew tap ilakiancs/quickgpt
brew install --cask quickgpt
```

Grant Accessibility permission for global shortcuts:

```
System Settings → Privacy & Security → Accessibility → QuickGPT
```

### Usage

| Action | Shortcut |
|---|---|
| Toggle panel | `⌥X` (change in Settings) |
| Open from menu bar | Click brain icon |
| Close panel | `Escape`, `⌘W` or click outside |
| New chat / reload | `⌘N` / `⌘R` |
| Back | Header back button or two-finger swipe |
| Zoom | `⌘+` / `⌘-` / `⌘0` |
| Keep open while working | Pin button in the header |
| Context menu | Right-click icon |

Drag the panel's edges to resize it; the size is remembered. Links to other sites open in your default browser.

Sign in once with your ChatGPT account. Session persists across restarts.

### Uninstall

```bash
brew uninstall --cask quickgpt
brew untap ilakiancs/quickgpt
```

---

## Development

### Build from source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/Ilakiancs/QuickGPT.git
cd QuickGPT
make install
```

### Commands

| Command | Description |
|---|---|
| `make build` | Compile the app |
| `make run` | Build and launch |
| `make install` | Install to /Applications |
| `make uninstall` | Remove from /Applications |
| `make release` | Create distributable zip |

---

<div align="center">

MIT License

</div>
