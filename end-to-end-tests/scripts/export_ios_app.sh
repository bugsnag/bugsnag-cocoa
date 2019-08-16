#!/usr/bin/env bash

rm -rf test-fixture

cd end-to-end-tests/features/fixtures/ios-swift-cocoapods/

pod install

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -archivePath archive/iosTestApp.xcarchive \
  -quiet \
  archive

xcodebuild -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist

cd ../../../..

mkdir -p test-fixture

cp end-to-end-tests/features/fixtures/ios-swift-cocoapods/output/iOSTestApp.ipa test-fixture/iOSTestApp.ipa