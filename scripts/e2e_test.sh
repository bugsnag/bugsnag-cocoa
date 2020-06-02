#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: e2e_test.sh <feature> [DEVICE_TYPE=IOS_13] [MAZE_ARGS]"
  echo
  echo "    DEVICE_TYPE is one of (IOS_10, IOS_11, IOS_12, IOS_13), with use detected by the "
  echo "      argument starting with \"IOS\""
  echo
  echo "    MAZE_ARGS is any number of arguments to be passed to Maze Runner"
  echo
  exit 1
fi;

# Ensure feature file exists
FEATURE=$1
if [ ! -f "$FEATURE" ]; then
    echo "File $FEATURE not found"
    exit 1
fi

shift

if [ $# -gt 0 ] && [[ "$1" == IOS* ]]; then
  DEVICE=$1
  shift
else
   DEVICE=IOS_13
fi;

MAZE_ARGS="$*" TEST_FEATURE=$FEATURE DEVICE_TYPE=$DEVICE make e2e
