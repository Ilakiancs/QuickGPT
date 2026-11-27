#!/usr/bin/env bash
# Points the Homebrew cask in Ilakiancs/homebrew-quickgpt at a published release.
#
#   scripts/update-cask.sh <version> <SHA256SUMS.txt>        # commit to the tap (needs GH_TOKEN or gh auth)
#   scripts/update-cask.sh <version> <SHA256SUMS.txt> --print  # just print the cask
set -euo pipefail

VERSION="${1:?usage: update-cask.sh <version> <SHA256SUMS.txt> [--print]}"
SUMS="${2:?usage: update-cask.sh <version> <SHA256SUMS.txt> [--print]}"
MODE="${3:-}"
TAP_REPO=Ilakiancs/homebrew-quickgpt
CASK_PATH=Casks/quickgpt.rb

sha_for() {
  local sha
  sha=$(awk -v f="QuickGPT-${VERSION}-$1.zip" '$2 == f { print $1 }' "$SUMS")
  if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: no checksum for QuickGPT-${VERSION}-$1.zip in $SUMS" >&2
    exit 1
  fi
  echo "$sha"
}
ARM_SHA=$(sha_for arm64)
INTEL_SHA=$(sha_for x86_64)

CASK=$(cat <<EOF
cask "quickgpt" do
  arch arm: "arm64", intel: "x86_64"

  version "${VERSION}"
  sha256 arm:   "${ARM_SHA}",
         intel: "${INTEL_SHA}"

  url "https://github.com/Ilakiancs/QuickGPT/releases/download/v#{version}/QuickGPT-#{version}-#{arch}.zip"
  name "QuickGPT"
  desc "Lightweight ChatGPT menu bar client"
  homepage "https://github.com/Ilakiancs/QuickGPT"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "QuickGPT.app"

  uninstall quit: "com.personal.QuickGPT"

  zap trash: [
    "~/Library/Caches/com.personal.QuickGPT",
    "~/Library/HTTPStorages/com.personal.QuickGPT.binarycookies",
    "~/Library/Preferences/com.personal.QuickGPT.plist",
    "~/Library/WebKit/com.personal.QuickGPT",
  ]
end
EOF
)

if [[ "$MODE" == "--print" ]]; then
  echo "$CASK"
  exit 0
fi

CURRENT_SHA=$(gh api "repos/$TAP_REPO/contents/$CASK_PATH" --jq .sha)
gh api -X PUT "repos/$TAP_REPO/contents/$CASK_PATH" \
  -f message="Update quickgpt to ${VERSION}" \
  -f content="$(printf '%s\n' "$CASK" | base64)" \
  -f sha="$CURRENT_SHA" \
  --jq '.commit.html_url'
