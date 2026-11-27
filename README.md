<div align="center">

# QuickGPT

**Native ChatGPT client for macOS, built in Swift**

[![CI](https://github.com/Ilakiancs/QuickGPT/actions/workflows/ci.yml/badge.svg)](https://github.com/Ilakiancs/QuickGPT/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Ilakiancs/QuickGPT)](https://github.com/Ilakiancs/QuickGPT/releases/latest)
[![License: MIT](https://img.shields.io/github/license/Ilakiancs/QuickGPT)](LICENSE)

[Getting started](#getting-started) · [Development](#development) · [Changelog](CHANGELOG.md)

</div>

<br>

A lightweight menu bar app that puts ChatGPT one shortcut away. No Electron, no browser tabs, no distractions. Pure Swift and WebKit, optimized for speed.

| | |
|---|---|
| **Platform** | macOS 13.0+ (Ventura and later), Apple Silicon and Intel |
| **Stack** | Swift 5.9, SwiftUI, WebKit |
| **Binary size** | ~2 MB |
| **Memory** | ~80 MB idle |

---

## Getting started

### Install

With [Homebrew](https://brew.sh) (picks the right build for your Mac):

```bash
brew tap ilakiancs/quickgpt
brew install --cask quickgpt
```

Or download from the [latest release](https://github.com/Ilakiancs/QuickGPT/releases/latest):

| Mac | Download |
|---|---|
| Apple Silicon (M1 and later) | `QuickGPT-<version>-arm64.zip` |
| Intel | `QuickGPT-<version>-x86_64.zip` |

Unzip and move `QuickGPT.app` to `/Applications`. QuickGPT isn't notarized yet: if macOS blocks the first launch, open **System Settings → Privacy & Security** and click **Open Anyway**.

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
brew uninstall --cask quickgpt   # add --zap to also remove the saved session and settings
brew untap ilakiancs/quickgpt
```

---

## Development

### Build from source

Requires Xcode 16 or later.

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
| `make test` | Run unit tests |
| `make install` | Install to /Applications |
| `make uninstall` | Remove from /Applications |
| `make release` | Build Apple Silicon and Intel zips plus `SHA256SUMS.txt` into `dist/` |

### Releasing

1. Move the **Unreleased** notes in [`CHANGELOG.md`](CHANGELOG.md) under a new version heading.
2. Set `CFBundleShortVersionString` (and bump `CFBundleVersion`) in `Resources/Info.plist`.
3. Merge to `main`, then tag and push: `git tag -a v1.2.0 -m "QuickGPT 1.2.0" && git push origin v1.2.0`.

The [Release workflow](.github/workflows/release.yml) tests, builds both architectures, and publishes the GitHub release with notes from the changelog. It also updates the Homebrew cask when the `HOMEBREW_TAP_TOKEN` secret is set; otherwise run `scripts/update-cask.sh <version> dist/SHA256SUMS.txt` after downloading the release's `SHA256SUMS.txt`.

### Contributing

Issues and pull requests are welcome. Please report security problems privately; see [SECURITY.md](SECURITY.md).

---

<div align="center">

MIT License

</div>
