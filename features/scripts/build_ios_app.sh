#!/usr/bin/env bash

if [ ! -d "iOSTestApp.xcworkspace" ]; then
    cd "$(dirname "$0")/.."
fi

rm -rf build
xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 8,OS=12.1' \
  -derivedDataPath build \
  -quiet \
  clean build
