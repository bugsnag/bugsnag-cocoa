#!/bin/bash

if [ $# -eq 0 ] || [ $# -gt 2 ]; then
  echo "Usage: e2e_test.sh <feature> [DEVICE_TYPE=IOS_13]"
  echo "  where DEVICE_TYPE is one of (IOS_10, IOS_11, IOS_12, IOS_13)"
  exit 1
fi;

FEATURE=$1
[ $# -eq 2 ] && DEVICE=$2 || DEVICE=IOS_13

TEST_FEATURE=$FEATURE DEVICE_TYPE=$DEVICE make e2e
