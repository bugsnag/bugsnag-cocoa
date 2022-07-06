#!/usr/bin/env bash

set -euo pipefail

cd features/fixtures/macos

echo "--- macOSTestApp: pod install"

pod install

echo "--- macOSTestApp: xcodebuild archive"

BUILD_ARGS=(
  -workspace macOSTestApp.xcworkspace
  -scheme macOSTestApp
  -destination generic/platform=macOS
  -configuration Debug
  -archivePath archive/macOSTestApp.xcarchive
  -quiet
  archive
  ONLY_ACTIVE_ARCH=NO
)

if [ "${ENABLE_CODE_COVERAGE:-}" = YES ]; then
  BUILD_ARGS+=(
    OTHER_CFLAGS='$(inherited) -fprofile-instr-generate -fcoverage-mapping'
    OTHER_LDFLAGS='$(inherited) -fprofile-instr-generate'
    OTHER_SWIFT_FLAGS='$(inherited) -profile-generate -profile-coverage-mapping'
  )
fi

xcodebuild "${BUILD_ARGS[@]}"

echo "--- macOSTestApp: xcodebuild -exportArchive"

xcrun xcodebuild \
  -exportArchive \
  -exportPath output/ \
  -exportOptionsPlist exportOptions.plist \
  -archivePath archive/macOSTestApp.xcarchive \
  -destination generic/platform=macOS \
  -quiet

cd output

echo "--- macOSTestApp: zip"

zip -qr macOSTestApp.zip macOSTestApp.app
