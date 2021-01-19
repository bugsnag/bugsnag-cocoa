#!/usr/bin/env sh

if [[ "$BUILDKITE_MESSAGE" == *"[barebones ci]"* ]]; then
  echo "Running barebones build due to commit message\n"
elif [[ "$BUILDKITE_MESSAGE" == *"[full ci]"* ||
  "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" == "master" ||
  "$BUILDKITE_BRANCH" == "master" ||
  ! -z "$FULL_SCHEDULED_BUILD" ]]; then
  echo "Running full build"
  buildkite-agent pipeline upload .buildkite/pipeline.quick.yml
  buildkite-agent pipeline upload .buildkite/pipeline.full.yml
elif [[ "$BUILDKITE_MESSAGE" == *"[pre-release ci]"* ||
  "$BUILDKITE_BRANCH" == "next" ]]; then
  echo "Running pre-release build"
  buildkite-agent pipeline upload .buildkite/pipeline.quick.yml
  buildkite-agent pipeline upload .buildkite/block.full.yml
elif [[ "$BUILDKITE_MESSAGE" == *"[integration ci]"* ||
  "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" == "next" ]]; then
  echo "Running integration build"
  buildkite-agent pipeline upload .buildkite/block.quick.yml
else
  echo "Running barebones build"
fi

