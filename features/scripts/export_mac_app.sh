#!/usr/bin/env bash

set -o errexit

cd features/fixtures/macos

echo "--- macOSTestApp: pod install"

pod install

echo "--- macOSTestApp: xcodebuild archive"

xcrun xcodebuild \
  -workspace macOSTestApp.xcworkspace \
  -scheme macOSTestApp \
  -configuration Debug \
  -archivePath archive/macOSTestApp.xcarchive \
  -quiet \
  archive

echo "--- macOSTestApp: xcodebuild -exportArchive"

xcrun xcodebuild \
  -exportArchive \
  -exportPath output/ \
  -exportOptionsPlist exportOptions.plist \
  -archivePath archive/macOSTestApp.xcarchive \
  -quiet

cd output

echo "--- macOSTestApp: zip"

zip -r macOSTestApp.zip macOSTestApp.app
