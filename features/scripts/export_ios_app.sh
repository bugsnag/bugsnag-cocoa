#!/usr/bin/env bash

set -o errexit

# "Release" or "Debug" must be specified
if [ "$1" != "Release" ] && [ "$1" != "Debug" ]; then
  echo "Usage: $0 [release|debug]"
  exit 1
fi

BUILD_CONFIGURATION=$1
pushd features/fixtures/ios

  echo "--- iOSTestApp: xcodebuild archive"

  #
  # Using CLANG_ENABLE_MODULES=NO to surface build errors
  # https://github.com/bugsnag/bugsnag-cocoa/pull/1284
  #

  xcrun xcodebuild \
    -scheme iOSTestApp \
    -workspace iOSTestApp.xcworkspace \
    -destination generic/platform=iOS \
    -configuration ${BUILD_CONFIGURATION} \
    -archivePath archive/iosTestApp.xcarchive \
    -allowProvisioningUpdates \
    -quiet \
    archive \
    CLANG_ENABLE_MODULES=NO \
    GCC_PREPROCESSOR_DEFINITIONS='$(inherited) BSG_LOG_LEVEL=BSG_LOGLEVEL_DEBUG BSG_KSLOG_ENABLED=1'

  echo "--- iOSTestApp: xcodebuild -exportArchive"

  xcrun xcodebuild \
    -exportArchive \
    -archivePath archive/iosTestApp.xcarchive \
    -destination generic/platform=iOS \
    -exportPath output/ \
    -quiet \
    -exportOptionsPlist exportOptions.plist

  pushd output
    mv iOSTestApp.ipa iOSTestApp_$BUILD_CONFIGURATION.ipa
  popd
popd
