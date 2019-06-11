#!/usr/bin/env bash

if [ ! -d "iOSTestApp.xcworkspace" ]; then
    cd "$(dirname "$0")/.."
fi

rm -rf build
xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 8,OS=$MAZE_SDK" \
  -derivedDataPath build \
  -quiet \
  clean build
