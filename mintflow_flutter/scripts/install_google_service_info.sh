#!/usr/bin/env bash
# Copy a downloaded Firebase iOS plist into the Runner target.
# Usage: ./scripts/install_google_service_info.sh ~/Downloads/GoogleService-Info.plist
set -euo pipefail
SRC="${1:?Path to GoogleService-Info.plist required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ios/Runner/GoogleService-Info.plist"
test -f "$SRC" || { echo "Not found: $SRC"; exit 1; }
cp "$SRC" "$DEST"
# Basic sanity: bundle id
if ! grep -q 'app.mintflow.ios' "$DEST"; then
  echo "WARNING: plist may not contain bundle id app.mintflow.ios — check Firebase iOS app config."
fi
echo "Installed → $DEST"
echo "Next: Firebase Console → Project Settings → Cloud Messaging → upload APNs Auth Key (.p8)."
