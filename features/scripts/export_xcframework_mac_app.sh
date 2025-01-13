#!/usr/bin/env bash

set -euo pipefail

pushd features/fixtures/macos

  echo "--- macOSTestAppXcFramework: xcodebuild archive"

  BUILD_ARGS=(
    -workspace macOSTestAppXcFramework.xcodeproj/project.xcworkspace
    -scheme macOSTestAppXcFramework
    -destination generic/platform=macOS
    -configuration Release
    -archivePath archive/macOSTestAppXcFramework.xcarchive
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

  echo "--- macOSTestAppXcFramework: xcodebuild -exportArchive"

  xcrun xcodebuild \
    -exportArchive \
    -exportPath output/ \
    -exportOptionsPlist exportOptions.plist \
    -archivePath archive/macOSTestAppXcFramework.xcarchive \
    -destination generic/platform=macOS \
    -quiet

  pushd output
    echo "--- macOSTestApp: zip"
    zip -qr macOSTestAppXcFramework.zip macOSTestAppXcFramework.app
  popd
popd
