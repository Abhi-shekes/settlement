#!/usr/bin/env bash
# Build a release APK and/or AAB with a proper, version-stamped filename.
#
# Flutter always writes "app-release.apk", so this script builds and then copies
# the output to dist/Settlement-<version>[-<build>].<ext>, matching what CI
# attaches to GitHub Releases.
#
# Usage:
#   ./scripts/build.sh            # APK only
#   ./scripts/build.sh apk        # APK only
#   ./scripts/build.sh aab        # App Bundle only
#   ./scripts/build.sh all        # both
#   BUILD_NUMBER=42 ./scripts/build.sh all   # stamp a build number too
set -euo pipefail

cd "$(dirname "$0")/.."

# Read versionName from pubspec.yaml (the part before any "+").
VERSION="$(grep '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//; s/\+.*//')"
APP="Settlement"
SUFFIX="${VERSION}"
[ -n "${BUILD_NUMBER:-}" ] && SUFFIX="${VERSION}-${BUILD_NUMBER}"

TARGET="${1:-apk}"
BN_ARG=()
[ -n "${BUILD_NUMBER:-}" ] && BN_ARG=(--build-number="${BUILD_NUMBER}")

mkdir -p dist

build_apk() {
  echo "▶ Building APK ${SUFFIX}…"
  flutter build apk --release --build-name="${VERSION}" "${BN_ARG[@]}"
  cp build/app/outputs/flutter-apk/app-release.apk "dist/${APP}-${SUFFIX}.apk"
  echo "✓ dist/${APP}-${SUFFIX}.apk"
}

build_aab() {
  echo "▶ Building App Bundle ${SUFFIX}…"
  flutter build appbundle --release --build-name="${VERSION}" "${BN_ARG[@]}"
  cp build/app/outputs/bundle/release/app-release.aab "dist/${APP}-${SUFFIX}.aab"
  echo "✓ dist/${APP}-${SUFFIX}.aab"
}

case "$TARGET" in
  apk) build_apk ;;
  aab) build_aab ;;
  all) build_apk; build_aab ;;
  *) echo "Unknown target '$TARGET' (use: apk | aab | all)"; exit 1 ;;
esac
