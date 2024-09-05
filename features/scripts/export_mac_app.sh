#!/usr/bin/env bash

set -euo pipefail

# "Release" or "Debug" must be specified
if [ "$1" != "Release" ] && [ "$1" != "Debug" ]; then
  echo "Usage: $0 [release|debug]"
  exit 1
fi

BUILD_CONFIGURATION=$1

pushd features/fixtures/macos

  echo "--- macOSTestApp: xcodebuild archive"

  BUILD_ARGS=(
    -workspace macOSTestApp.xcworkspace
    -scheme macOSTestApp
    -destination generic/platform=macOS
    -configuration ${BUILD_CONFIGURATION}
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

  pushd output
    echo "--- macOSTestApp: zip"
    zip -qr macOSTestApp_$BUILD_CONFIGURATION.zip macOSTestApp.app
  popd
popd
