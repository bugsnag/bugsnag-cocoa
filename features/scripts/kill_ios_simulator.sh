#!/usr/bin/env bash

xcrun simctl uninstall "$iOS_Simulator" com.bugsnag.iOSTestApp
xcrun simctl shutdown "$iOS_Simulator"
