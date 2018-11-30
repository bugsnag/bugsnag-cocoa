#!/usr/bin/env bash

xcrun simctl list | grep "maze-sim" | awk '{gsub(/\(|\)/, "", $2); print $2 };' | xargs xcrun simctl delete; true
