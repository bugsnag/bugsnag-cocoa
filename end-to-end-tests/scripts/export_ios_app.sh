#!/usr/bin/env bash

rm -rf test-outputs

cd test-fixture/ios-swift-cocoapods/

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

cd ../../

mkdir -p test-outputs/dSYMs

cp test-fixture/ios-swift-cocoapods/output/iOSTestApp.ipa test-outputs/iOSTestApp.ipa
cp -r test-fixture/ios-swift-cocoapods/archive/iosTestApp.xcarchive/dSYMs/ test-outputs/dSYMs/
tar -czf test-outputs/dSYMs.zip test-outputs/dSYMs