#!/bin/zsh
set -eu
reference_repo="$(cd "$(dirname "$0")/.." && pwd)"
reference_build="${REFERENCE_BUILD_DIR:-/private/tmp/vaultline-reference-dev}"
cd "$reference_repo/macos"
xcodegen generate
scripts/post-xcodegen.sh
xcodebuild build -project Snapwell.xcodeproj -scheme Snapwell -destination 'platform=macOS' \
  -derivedDataPath "$reference_build" CODE_SIGNING_ALLOWED=NO
open "$reference_build/Build/Products/Debug/Snapwell.app"
