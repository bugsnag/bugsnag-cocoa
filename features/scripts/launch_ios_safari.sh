#!/usr/bin/env bash

xcrun simctl openurl "$iOS_Simulator" "http://example.com"
# Run twice to fix bug (?) in Xcode 10.2 / iOS 12.2 which switches back to
# test app after opening the URL
xcrun simctl openurl "$iOS_Simulator" "http://example.com"
