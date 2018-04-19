#!/usr/bin/env bash

xcrun simctl list | grep "iPhone8-11.2" | awk '{gsub(/\(|\)/, "", $2); print $2 };' | xargs xcrun simctl delete; true
