ifeq ($(SDK),)
 SDK=iphonesimulator11.2
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
  BUILD_ONLY_FLAGS=-sdk $(SDK) -configuration Debug -destination "platform=tvOS Simulator,name=Apple TV"
 else
  PLATFORM=iOS
  RELEASE_DIR=Release-iphoneos
  BUILD_FLAGS=-workspace iOS.xcworkspace -scheme Bugsnag
  BUILD_ONLY_FLAGS=-sdk $(SDK) -destination "platform=iOS Simulator,name=iPhone 5" -configuration Debug
 endif
endif
XCODEBUILD=set -o pipefail && xcodebuild
PRESET_VERSION=$(shell cat VERSION)
ifneq ($(strip $(shell which xcpretty)),)
 FORMATTER = | tee xcodebuild.log | xcpretty -c
endif

all: build

# Generated framework package for Bugsnag for either iOS or macOS
build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework:
	@xcodebuild $(BUILD_FLAGS) \
		-configuration Release \
		-derivedDataPath build clean build $(FORMATTER)

# Compressed bundle for release version of Bugsnag framework
build/Bugsnag-%-$(PRESET_VERSION).zip: build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework
	@cd build/Build/Products/$(RELEASE_DIR); \
		zip --symlinks -rq ../../../Bugsnag-$*-$(PRESET_VERSION).zip Bugsnag.framework

.PHONY: all build test bump

bootstrap:
	@bundle install

build:
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) build $(FORMATTER)

bump:
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number bump`)
endif
	@echo Bumping the version number to $(VERSION)
	@echo $(VERSION) > VERSION
	@sed -i '' "s/\"version\": .*,/\"version\": \"$(VERSION)\",/" Bugsnag.podspec.json
	@sed -i '' "s/\"tag\": .*/\"tag\": \"v$(VERSION)\"/" Bugsnag.podspec.json
	@sed -i '' "s/NOTIFIER_VERSION = .*;/NOTIFIER_VERSION = @\"$(VERSION)\";/" Source/BugsnagNotifier.m

# Makes a release and pushes to github/cocoapods
release:
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number release`)
endif
	make VERSION=$(VERSION) bump && git commit -am "v$(VERSION)" && git tag v$(VERSION) \
	&& git push origin && git push --tags && pod trunk push


clean:
	@$(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -rf build

test:
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

e2e:
	@bundle exec maze-runner

archive: build/Bugsnag-$(PLATFORM)-$(PRESET_VERSION).zip
