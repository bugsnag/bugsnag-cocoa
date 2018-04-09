#!/usr/bin/env bash

pkill Simulator
# Simulators used in the test suite:
xcrun simctl boot "iPhone8-11.3"; true
# If appending to this list, add to uninstall_ios_app.sh as well
