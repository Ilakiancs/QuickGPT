#!/bin/bash
set -e

echo "Building QuickGPT..."
swift build -c release

echo "Creating app bundle..."
mkdir -p QuickGPT.app/Contents/MacOS
mkdir -p QuickGPT.app/Contents/Resources

cp .build/release/QuickGPT QuickGPT.app/Contents/MacOS/

echo "Build complete: QuickGPT.app"
echo ""
echo "To install to Applications:"
echo "  cp -r QuickGPT.app /Applications/"
echo ""
echo "To run:"
echo "  open QuickGPT.app"
