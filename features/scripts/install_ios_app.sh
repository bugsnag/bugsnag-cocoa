#!/usr/bin/env bash

xcrun simctl boot "$iOS_Simulator"
sleep 2
xcrun simctl install "$iOS_Simulator" \
  test-fixture/ios-swift-cocoapods/build/Build/Products/Debug-iphonesimulator/iOSTestApp.app
