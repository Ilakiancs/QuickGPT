# QuickGPT

A lightweight, fast ChatGPT menu bar app for macOS. Personal alternative to MacGPT.

## Features

- **Menu bar access** - Click brain icon to open ChatGPT panel
- **Global shortcut** - ⌘⇧Space to toggle from anywhere
- **Persistent session** - Login once, stays logged in
- **Instant access** - ChatGPT preloads in background
- **Click outside to dismiss** - Clean, non-intrusive UX

## Requirements

- macOS 13.0+
- Swift 5.9+

## Build

```bash
swift build -c release
./build.sh
```

## Install

```bash
cp -r QuickGPT.app /Applications/
```

## Usage

| Action | Result |
|--------|--------|
| Click menu bar icon | Toggle ChatGPT panel |
| Right-click icon | Context menu |
| ⌘⇧Space | Global toggle shortcut |

## Permissions

Grant **Accessibility** permission for global shortcuts:
System Settings → Privacy & Security → Accessibility → QuickGPT
