#!/usr/bin/env bash

INSTALL_PATH=build/Build/Products/Debug-iphonesimulator/iOSTestApp.app
OS_VERSION="11.3"

# Create required simulators
xcrun simctl create "iPhone8-$OS_VERSION" "iPhone 8" "$OS_VERSION"

# Simulators used in the test suite:
xcrun simctl boot "iPhone8-$OS_VERSION"; true

# Install the app on each simulator
xcrun simctl install "iPhone8-$OS_VERSION" "$INSTALL_PATH"

# Preheat the simulators by triggering a crash
xcrun simctl launch "iPhone8-$OS_VERSION" com.bugsnag.iOSTestApp \
    "EVENT_TYPE=preheat"
