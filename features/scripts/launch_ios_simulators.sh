#!/usr/bin/env bash

INSTALL_PATH=build/Build/Products/Debug-iphonesimulator/iOSTestApp.app

# Create required simulators
xcrun simctl create "iPhone8-11.2" "iPhone 8" "11.2"

# Simulators used in the test suite:
xcrun simctl boot "iPhone8-11.2"; true

# Install the app on each simulator
xcrun simctl install "iPhone8-11.2" "$INSTALL_PATH"

# Preheat the simulators by triggering a crash
xcrun simctl launch "iPhone8-11.2" com.bugsnag.iOSTestApp \
    "EVENT_TYPE=preheat"
