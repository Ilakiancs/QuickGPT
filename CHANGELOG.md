# Changelog

All notable changes to QuickGPT are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Updated the Defaults library to 9.x. Building from source now requires Xcode 26 (Swift 6.2); CI and releases run on GitHub's macOS 26 runners.

## [1.1.1] - 2026-11-27

### Added
- Separate downloads for Apple Silicon (`arm64`) and Intel (`x86_64`) Macs, with a `SHA256SUMS.txt` checksum file.
- The Homebrew cask installs the right build for your Mac automatically.
- Releases are now built and published by GitHub Actions; every pull request is tested and built for both architectures.

## [1.1.0] - 2026-11-27

### Added
- ⌥X toggles the panel (change it in Settings → Shortcuts). The panel opens with the cursor in the prompt, and focus returns to your previous app when it closes.
- Pin button to keep the panel open while you work in other apps.
- Resizable panel that remembers its size; zoom with ⌘+ / ⌘- / ⌘0.
- File attachments and downloads (saved to ~/Downloads).
- In-panel shortcuts: ⌘N new chat, ⌘R reload, ⌘W or Esc to close.
- Launch at login option.

### Fixed
- Copying text no longer includes buttons and other UI ("Log in", "Copy code", "ChatGPT said:").
- Back no longer lands on an expired sign-in page ("Your sign-in session is no longer valid").
- Esc closes ChatGPT's own menus before closing the panel.
- Links to other sites open in your browser instead of replacing the chat.
- A retry page replaces the blank panel when ChatGPT can't load; the page recovers after a crash.
- Settings… opens on macOS 14 and later, and the Shortcuts tab no longer crashes in downloaded builds.

### Security
- Pages can no longer open local files or apps; only links you click are handed to other apps.

### Removed
- Voice mode. The app never asks for microphone or camera access.

## [1.0.0] - 2026-11-27

### Added
- Menu bar ChatGPT client with a global shortcut (⌘⇧Space).
- Persistent sign-in session.
- Escape or click outside to dismiss; back button.

[Unreleased]: https://github.com/Ilakiancs/QuickGPT/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/Ilakiancs/QuickGPT/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/Ilakiancs/QuickGPT/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Ilakiancs/QuickGPT/releases/tag/v1.0.0
