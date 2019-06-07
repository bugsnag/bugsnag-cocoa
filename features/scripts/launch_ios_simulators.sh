#!/usr/bin/env bash

INSTALL_PATH=build/Build/Products/Debug-iphonesimulator/iOSTestApp.app
OS_VERSION=${MAZE_SDK:="12.1"}

# Create required simulators
xcrun simctl create "maze-sim" "iPhone 8" "$OS_VERSION"

# Simulators used in the test suite:
xcrun simctl boot "maze-sim"; true

# Install the app on each simulator
xcrun simctl install "maze-sim" "$INSTALL_PATH"

# Preheat the simulators by triggering a crash
xcrun simctl launch "maze-sim" com.bugsnag.iOSTestApp \
    "EVENT_TYPE=preheat"
