ifeq ($(SDK),)
 SDK=iphonesimulator9.2
endif
IOS_BUILD_FLAGS=-workspace Bugsnag.xcworkspace -scheme BugsnagiOS -sdk $(SDK) -destination "platform=iOS Simulator,name=iPhone 5" -configuration Debug
OSX_BUILD_FLAGS=-workspace Bugsnag.xcworkspace -scheme BugsnagOSX CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
XCODEBUILD=set -o pipefail && xcodebuild
VERSION=$(shell cat VERSION)
ifneq ($(strip $(shell which xcpretty)),)
 FORMATTER = | tee xcodebuild.log | xcpretty
endif
KSCRASH_DEP = Carthage/Checkouts/KSCrash

$(KSCRASH_DEP):
	git submodule update --init

build/Release/%.framework:
	xcodebuild -target $* build $(FORMATTER)

build/Release/%-$(VERSION).zip: build/Release/%.framework
	cd build/Release; \
	zip --symlinks -r $*.zip $*.framework

.PHONY: all build test

all: build

bootstrap:
	@gem install xcpretty --quiet --no-ri --no-rdoc

build: $(KSCRASH_DEP)
	$(XCODEBUILD) $(IOS_BUILD_FLAGS) build $(FORMATTER)

clean: $(KSCRASH_DEP)
	$(XCODEBUILD) $(IOS_BUILD_FLAGS) clean $(FORMATTER)
	@rm -r build

test:
ifeq ($(BUILD_OSX), 1)
	@$(MAKE) test-osx
else
	@$(MAKE) test-ios
endif

test-ios: $(KSCRASH_DEP)
	$(XCODEBUILD) $(IOS_BUILD_FLAGS) test $(FORMATTER)

test-osx: $(KSCRASH_DEP)
	$(XCODEBUILD) $(OSX_BUILD_FLAGS) test $(FORMATTER)

release: build/Release/Bugsnag-$(VERSION).zip build/Release/BugsnagOSX-$(VERSION).zip
	@open .
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?tag=v'$(VERSION)

