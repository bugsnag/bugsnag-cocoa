#!/usr/bin/env bash

set -o errexit

cd features/fixtures/ios

echo "--- iOSTestAppXcFramework: xcodebuild archive"

#
# Using CLANG_ENABLE_MODULES=NO to surface build errors
# https://github.com/bugsnag/bugsnag-cocoa/pull/1284
#

xcrun xcodebuild \
  -scheme iOSTestAppXcFramework \
  -workspace iOSTestAppXcFramework.xcworkspace \
  -destination generic/platform=iOS \
  -configuration Release \
  -archivePath archive/iosTestAppXcFramework.xcarchive \
  -allowProvisioningUpdates \
  -quiet \
  archive \
  CLANG_ENABLE_MODULES=NO \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) BSG_LOG_LEVEL=BSG_LOGLEVEL_DEBUG BSG_KSLOG_ENABLED=1'

echo "--- iOSTestAppXcFramework: xcodebuild -exportArchive"

xcrun xcodebuild \
  -exportArchive \
  -archivePath archive/iosTestAppXcFramework.xcarchive \
  -destination generic/platform=iOS \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist
