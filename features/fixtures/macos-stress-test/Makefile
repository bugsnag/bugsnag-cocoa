.PHONY: all build clean run

all: build

build:
	pod install
	xcodebuild \
		-workspace BugsnagStressTest.xcworkspace \
		-scheme BugsnagStressTest \
		-configuration Release \
		-derivedDataPath build/DerivedData \
		-quiet \
		install DSTROOT=build

clean:
	rm -rf build Pods *.log

run:
	QUIET=true /usr/bin/time -l ./build/usr/local/bin/BugsnagStressTest
	rm -rf $(HOME)/Library/Application\ Support/com.bugsnag.Bugsnag
	@echo "macOS stress-test complete"
