#!/usr/bin/env bash

# TODO: sub hardcoded device for $SIMULATOR
xcrun simctl boot "iPhone 8"
sleep 2
xcrun simctl install "iPhone 8" \
  features/fixtures/ios-swift-cocoapods/build/Build/Products/Debug-iphonesimulator/iOSTestApp.app
