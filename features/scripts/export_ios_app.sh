#!/usr/bin/env bash

set -o errexit

cd features/fixtures/ios

echo "--- iOSTestApp: xcodebuild archive"

#
# Using CLANG_ENABLE_MODULES=NO to surface build errors
# https://github.com/bugsnag/bugsnag-cocoa/pull/1284
#

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -destination generic/platform=iOS \
  -configuration Debug \
  -archivePath archive/iosTestApp.xcarchive \
  -allowProvisioningUpdates \
  -quiet \
  archive \
  CLANG_ENABLE_MODULES=NO \
  GCC_PREPROCESSOR_DEFINITIONS='$(inherited) BSG_LOG_LEVEL=BSG_LOGLEVEL_DEBUG'

echo "--- iOSTestApp: xcodebuild -exportArchive"

xcrun xcodebuild \
  -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -destination generic/platform=iOS \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist
