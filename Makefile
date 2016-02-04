ifeq ($(IPHONE_SDK),)
 IPHONE_SDK=iphonesimulator9.2
endif
BUILD_FLAGS=-project Bugsnag.xcodeproj -scheme Bugsnag -sdk $(IPHONE_SDK) -destination "platform=iOS Simulator,name=iPhone 5" -configuration Debug
XCODEBUILD=set -o pipefail && xcodebuild
VERSION=$(shell cat VERSION)
ifneq ($(strip $(shell which xcpretty)),)
 FORMATTER = | tee xcodebuild.log | xcpretty
endif

build/Release/%.framework:
	xcodebuild -target $* build $(FORMATTER)

build/Release/%-$(VERSION).zip: build/Release/%.framework
	cd build/Release; \
	zip --symlinks -r $*.zip $*.framework

.PHONY: all build test

all: build

bootstrap:
	@gem install xcpretty --quiet --no-ri --no-rdoc

build:
	$(XCODEBUILD) $(BUILD_FLAGS) build $(FORMATTER)

clean:
	$(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -r build

test:
	$(XCODEBUILD) $(BUILD_FLAGS) test $(FORMATTER)

release: build/Release/Bugsnag-$(VERSION).zip build/Release/BugsnagOSX-$(VERSION).zip
	@open .
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?tag=v'$(VERSION)

