#!/bin/bash

set -o errexit
set -o nounset


echo "--- Prepare"

trap "echo '^^^ +++'" ERR

xcode_version_major=$(xcodebuild -version | head -n1 | cut -d ' ' -f 2 | cut -d . -f 1)

dir=features/fixtures/carthage

mkdir -p "$dir"

echo "git \"file://$(pwd)\" \"$(git rev-parse HEAD)\"" > "$dir"/Cartfile

cd "$dir"


for platform in iOS macOS tvOS
do
	cmdline=("carthage" "update" "--platform" "$platform")
	if [ "$xcode_version_major" -ge 12 ]
	then
		cmdline+=("--use-xcframeworks")
	fi
	echo "---" "${cmdline[@]}"
	"${cmdline[@]}"
done
