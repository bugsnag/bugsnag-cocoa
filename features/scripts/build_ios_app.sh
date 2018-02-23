#!/usr/bin/env bash

if [ ! -d "iOSTestApp.xcworkspace" ]; then
    cd "$(dirname "$0")/.."
fi

xcrun xcodebuild \
  -scheme iOSTestApp \
  -workspace iOSTestApp.xcworkspace \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 8,OS=11.2' \
  -derivedDataPath build \
  build
