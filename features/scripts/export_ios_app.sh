#!/usr/bin/env bash

set -o errexit

cd features/fixtures/ios

echo "--- iOSTestApp: xcodebuild archive"

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -archivePath archive/iosTestApp.xcarchive \
  -allowProvisioningUpdates \
  -quiet \
  archive \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) BSG_LOG_LEVEL=BSG_LOGLEVEL_DEBUG'

echo "--- iOSTestApp: xcodebuild -exportArchive"

xcrun xcodebuild \
  -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist
