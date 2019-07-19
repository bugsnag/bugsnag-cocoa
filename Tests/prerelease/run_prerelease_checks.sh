#!/usr/bin/env bash

# Run visibly to allow scripting access (pressing buttons, etc)
open $(xcode-select -p)/Applications/Simulator.app

bundle exec maze-runner Tests/prerelease/features/
