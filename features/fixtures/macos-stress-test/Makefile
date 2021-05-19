.PHONY: all build clean

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
