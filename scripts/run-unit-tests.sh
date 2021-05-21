#!/usr/bin/env bash

set -o nounset

xcresult=$(date '+BugsnagTests-%Y-%m-%d-%H-%M-%S.xcresult')

die() {
	status=$?
	echo "^^^ +++"
	mkdir -p logs
	[[ -f xcodebuild.log ]] && mv xcodebuild.log logs/
	[[ -d $xcresult ]] && zip -qr "logs/$xcresult.zip" "$xcresult"
	exit $status
}


echo "--- Analyze"

make analyze "$@" || die

rm -rf DerivedData


echo "--- Test"

make test XCODEBUILD_EXTRA_ARGS="-resultBundlePath $xcresult" "$@" || die

rm -rf "$xcresult"
