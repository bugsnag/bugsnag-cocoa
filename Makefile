ifeq ($(SDK),)
 SDK=iphonesimulator9.2
endif
ifeq ($(BUILD_OSX), 1)
 BUILD_FLAGS=-workspace OSX.xcworkspace -scheme Bugsnag
 BUILD_ONLY_FLAGS=CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
else
 BUILD_FLAGS=-workspace iOS.xcworkspace -scheme Bugsnag
 BUILD_ONLY_FLAGS=-sdk $(SDK) -destination "platform=iOS Simulator,name=iPhone 5" -configuration Debug
endif
XCODEBUILD=set -o pipefail && xcodebuild
VERSION=$(shell cat VERSION)
ifneq ($(strip $(shell which xcpretty)),)
 FORMATTER = | tee xcodebuild.log | xcpretty
endif

all: build

# Vendored dependency on KSCrash, pinned to the required version
KSCRASH_DEP = Carthage/Checkouts/KSCrash
$(KSCRASH_DEP):
	git submodule update --init

# Generated framework package for Bugsnag for either iOS or OS X
build/Release/%.framework:
	xcodebuild $(BUILD_FLAGS) build -configuration Release $(FORMATTER)

# Compressed bundle for release version of Bugsnag framework
build/Release/%-$(VERSION).zip: build/Release/%.framework
	cd build/Release; \
	zip --symlinks -r $*.zip $*.framework

.PHONY: all build test

bootstrap:
	@gem install xcpretty --quiet --no-ri --no-rdoc

build: $(KSCRASH_DEP)
	$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) build $(FORMATTER)

clean: $(KSCRASH_DEP)
	$(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -rf build

test: $(KSCRASH_DEP)
	$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

release: build/Release/Bugsnag-$(VERSION).zip build/Release/BugsnagOSX-$(VERSION).zip
	@open .
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?tag=v'$(VERSION)

