#!/usr/bin/env bash

set -o errexit
set -o verbose

cd features/fixtures/macos

xcrun xcodebuild \
  -workspace macOSTestApp.xcworkspace \
  -scheme macOSTestApp \
  -configuration Debug \
  -archivePath archive/macOSTestApp.xcarchive \
  -quiet \
  archive \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) BSG_LOG_LEVEL=BSG_LOGLEVEL_DEBUG'

xcrun xcodebuild \
  -exportArchive \
  -exportPath output/ \
  -exportOptionsPlist exportOptions.plist \
  -archivePath archive/macOSTestApp.xcarchive \
  -quiet

cd output

zip -r macOSTestApp.zip macOSTestApp.app
