#!/usr/bin/env bash

# Bring a previously running app to the foreground

xcrun simctl launch "$iOS_Simulator" com.bugsnag.iOSTestApp \
        "EVENT_TYPE=AutoCaptureRunScenario" \
        "BUGSNAG_API_KEY=$BUGSNAG_API_KEY" \
        "MOCK_API_PATH=http://localhost:$MOCK_API_PORT"
