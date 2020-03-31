#!/usr/bin/env bash

cd features/fixtures/ios-swift-cocoapods/

pod install

if [ $? -ne 0 ]
then
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

if [ $? -ne 0 ]
then
  echo "App could not be exported"
  exit 1
fi

xcrun xcodebuild -exportArchive \
  -archivePath archive/iosTestApp.xcarchive \
  -exportPath output/ \
  -quiet \
  -exportOptionsPlist exportOptions.plist

if [ $? -ne 0 ]; then
  echo "Archive could not be created"
  exit 1
fi