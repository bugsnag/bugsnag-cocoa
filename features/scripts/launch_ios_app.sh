#!/usr/bin/env bash

osascript -e 'launch application "Simulator"'
xcrun simctl launch --console booted com.bugsnag.iOSTestApp \
    "EVENT_TYPE=$EVENT_TYPE" \
    "EVENT_DELAY=$EVENT_DELAY" \
    "BUGSNAG_API_KEY=$BUGSNAG_API_KEY" \
    "MOCK_API_PATH=http://localhost:$MOCK_API_PORT"
