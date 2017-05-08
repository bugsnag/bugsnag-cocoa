ifeq ($(SDK),)
 SDK=iphonesimulator10.3
endif
ifeq ($(BUILD_OSX), 1)
 PLATFORM=OSX
 RELEASE_DIR=Release
 BUILD_FLAGS=-workspace OSX.xcworkspace -scheme Bugsnag
 BUILD_ONLY_FLAGS=CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
else
 ifeq ($(BUILD_TV), 1)
  PLATFORM=tvOS
  BUILD_FLAGS=-workspace tvOS.xcworkspace -scheme Bugsnag
  BUILD_ONLY_FLAGS=-sdk $(SDK) -configuration Debug -destination "platform=tvOS Simulator,name=Apple TV 1080p"
 else
  PLATFORM=iOS
  RELEASE_DIR=Release-iphoneos
  BUILD_FLAGS=-workspace iOS.xcworkspace -scheme Bugsnag
  BUILD_ONLY_FLAGS=-sdk $(SDK) -destination "platform=iOS Simulator,name=iPhone 5" -configuration Debug
 endif
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
	@git submodule update --init

# Generated framework package for Bugsnag for either iOS or macOS
build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework:
	@xcodebuild $(BUILD_FLAGS) \
		-configuration Release \
		-derivedDataPath build clean build $(FORMATTER)

# Compressed bundle for release version of Bugsnag framework
build/Bugsnag-%-$(VERSION).zip: build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework
	@cd build/Build/Products/$(RELEASE_DIR); \
		zip --symlinks -rq ../../../Bugsnag-$*-$(VERSION).zip Bugsnag.framework

.PHONY: all build test

bootstrap:
	@gem install xcpretty --quiet --no-ri --no-rdoc

build: $(KSCRASH_DEP)
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) build $(FORMATTER)

clean: $(KSCRASH_DEP)
	@$(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -rf build

test: $(KSCRASH_DEP)
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

archive: build/Bugsnag-$(PLATFORM)-$(VERSION).zip


