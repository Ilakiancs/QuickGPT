#!/usr/bin/env bash
# Prints GitHub release notes for a version: its CHANGELOG.md section plus download/install help.
#
#   scripts/release-notes.sh <version>
set -euo pipefail

VERSION="${1:?usage: release-notes.sh <version>}"
cd "$(dirname "$0")/.."

# The section between "## [<version>]" and the next "## [" heading.
SECTION=$(awk -v v="$VERSION" '
  index($0, "## [" v "]") == 1 { on = 1; next }
  on && /^## \[/ { exit }
  on { print }
' CHANGELOG.md)

if [[ -z "${SECTION//[[:space:]]/}" ]]; then
  echo "error: CHANGELOG.md has no entry for $VERSION" >&2
  exit 1
fi

cat <<EOF
${SECTION}

## Download

| Mac | File |
|---|---|
| Apple Silicon (M1 and later) | \`QuickGPT-${VERSION}-arm64.zip\` |
| Intel | \`QuickGPT-${VERSION}-x86_64.zip\` |

Not sure which you have? Apple menu → **About This Mac** → **Chip** (Apple M-series) or **Processor** (Intel).

Unzip and move \`QuickGPT.app\` to \`/Applications\`. Checksums are in \`SHA256SUMS.txt\` (\`shasum -a 256 -c SHA256SUMS.txt\`).

### Homebrew

\`\`\`bash
brew tap ilakiancs/quickgpt
brew install --cask quickgpt   # picks the right build for your Mac
\`\`\`

QuickGPT isn't notarized yet. If macOS blocks the first launch, open **System Settings → Privacy & Security** and click **Open Anyway**.

Requires macOS 13 Ventura or later.
EOF
