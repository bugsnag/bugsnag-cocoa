#!/usr/bin/env bash

OS_VERSION="11.3"

xcrun simctl list | grep "iPhone8-$OS_VERSION" | awk '{gsub(/\(|\)/, "", $2); print $2 };' | xargs xcrun simctl delete; true
