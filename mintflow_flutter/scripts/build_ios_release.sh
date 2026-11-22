#!/usr/bin/env bash
# Build a release IPA for TestFlight / App Store.
# Usage:
#   export REVENUECAT_IOS_PUBLIC_KEY=appl_xxx
#   ./scripts/build_ios_release.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://mintflow-api.up.railway.app}"
: "${REVENUECAT_IOS_PUBLIC_KEY:?Set REVENUECAT_IOS_PUBLIC_KEY=appl_...}"

echo "Building IPA → API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build ipa --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="REVENUECAT_IOS_PUBLIC_KEY=${REVENUECAT_IOS_PUBLIC_KEY}" \
  ${GOOGLE_CLIENT_ID:+--dart-define="GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}"} \
  ${GOOGLE_IOS_CLIENT_ID:+--dart-define="GOOGLE_IOS_CLIENT_ID=${GOOGLE_IOS_CLIENT_ID}"}

echo "IPA at build/ios/ipa/*.ipa — upload via Xcode Organizer or Transporter."
