# QuickGPT

A lightweight, fast ChatGPT menu bar app for macOS. Personal alternative to MacGPT.

## Features

- **Menu bar access** - Click brain icon to open ChatGPT panel
- **Global shortcut** - ⌘⇧Space to toggle from anywhere
- **Persistent session** - Login once, stays logged in
- **Instant access** - ChatGPT preloads in background
- **Click outside / Escape** - Clean dismissal

## Requirements

- macOS 13.0+
- Xcode Command Line Tools

## Development

```bash
# Build and run (dev mode - no install)
make run

# Build only
make build

# Install to /Applications
make install

# Uninstall
make uninstall

# Clean build
make clean

# Create release zip
make release
```

## Quick Install

```bash
git clone https://github.com/Ilakiancs/QuickGPT.git
cd QuickGPT
make install
```

## Usage

| Action | Result |
|--------|--------|
| Click menu bar icon | Toggle ChatGPT panel |
| Right-click icon | Context menu |
| ⌘⇧Space | Global toggle shortcut |
| Escape | Close panel |
| Click outside | Close panel |

## Permissions

Grant **Accessibility** permission for global shortcuts:

```
System Settings → Privacy & Security → Accessibility → QuickGPT
```

## License

MIT
