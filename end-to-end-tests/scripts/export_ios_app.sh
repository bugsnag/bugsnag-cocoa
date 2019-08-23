#!/usr/bin/env bash

rm -rf test-fixture

cd end-to-end-tests/features/fixtures/ios-swift-cocoapods/

rm -rf archive
rm -rf output

pod install

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -archivePath archive/iosTestApp.xcarchive \
  -allowProvisioningUpdates \
  -quiet \
  archive

xcrun xcodebuild -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist

cd ../../../..

mkdir -p test-fixture/dSYMs

cp end-to-end-tests/features/fixtures/ios-swift-cocoapods/output/iOSTestApp.ipa test-fixture/iOSTestApp.ipa
cp -r end-to-end-tests/features/fixtures/ios-swift-cocoapods/archive/iosTestApp.xcarchive/dSYMs/ test-fixture/dSYMs/
tar -czf test-fixture/dSYMs.zip test-fixture/dSYMs