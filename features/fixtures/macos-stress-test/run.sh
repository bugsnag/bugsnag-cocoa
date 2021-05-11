#!/bin/bash

cd "$(dirname "$0")"

QUIET=true ./build/usr/local/bin/BugsnagStressTest
RESULT=$?

rm -rf ~/Library/Application\ Support/com.bugsnag.Bugsnag

if [ "$RESULT" -ne "0" ]; then
	# Wait for the crash reporter to write a crash report
	sleep 5

	find ~/Library/Logs/DiagnosticReports \
		-name 'BugsnagStressTest_*.crash' \
		-newer build/usr/local/bin/BugsnagStressTest \
		-exec mv {} . \;
fi

echo "BugsnagStressTest exited with $RESULT"

exit $RESULT
