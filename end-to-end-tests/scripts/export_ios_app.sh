#!/usr/bin/env bash

rm -rf test-outputs

cd test-fixture/ios-swift-cocoapods/

rm -rf archive
rm -rf output

pod install

if [ $? -eq 0 ]; then
  echo "Pods could not be installed"
  exit 1
fi

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -archivePath archive/iosTestApp.xcarchive \
  -allowProvisioningUpdates \
  -quiet \
  archive

if [ $? -eq 0 ]; then
  echo "App could not be exported"
  exit 1
fi

xcrun xcodebuild -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist

if [ $? -eq 0 ]; then
  echo "Archive could not be created"
  exit 1
fi

cd ../../

mkdir -p test-outputs/dSYMs

cp test-fixture/ios-swift-cocoapods/output/iOSTestApp.ipa test-outputs/iOSTestApp.ipa
cp -r test-fixture/ios-swift-cocoapods/archive/iosTestApp.xcarchive/dSYMs/ test-outputs/dSYMs/
tar -czf test-outputs/dSYMs.zip test-outputs/dSYMs