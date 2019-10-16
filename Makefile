PLATFORM?=iOS
OS?=latest
TEST_CONFIGURATION?=Debug
BUILD_FLAGS=-project $(PLATFORM)/Bugsnag.xcodeproj -scheme Bugsnag -derivedDataPath build

ifeq ($(PLATFORM),OSX)
 SDK?=macosx
 RELEASE_DIR=Release
 BUILD_ONLY_FLAGS=-sdk $(SDK) CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
else
 ifeq ($(PLATFORM),tvOS)
  SDK?=appletvsimulator
  DESTINATION?=platform=tvOS Simulator,name=Apple TV,OS=$(OS)
 else
  SDK?=iphonesimulator
  DEVICE?=iPhone 5s
  DESTINATION?=platform=iOS Simulator,name=$(DEVICE),OS=$(OS)
  RELEASE_DIR=Release-iphoneos
 endif
 BUILD_ONLY_FLAGS=-sdk $(SDK) -destination "$(DESTINATION)" -configuration $(TEST_CONFIGURATION)
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

.PHONY: all build test bump prerelease release clean e2e

bootstrap: ## Install development dependencies
	@bundle install

build: ## Build the library
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) build $(FORMATTER)

build_ios_static: ## Build the static library target
	$(XCODEBUILD) -project iOS/Bugsnag.xcodeproj -scheme BugsnagStatic

build_carthage: ## Build the latest pushed commit with Carthage
	@mkdir -p features/fixtures/carthage-proj
	@echo 'git "file://$(shell pwd)" "'$(shell git rev-parse HEAD)'"' > features/fixtures/carthage-proj/Cartfile
	@cd features/fixtures/carthage-proj && carthage update --platform ios && \
		carthage update --platform macos

bump: ## Bump the version numbers to $VERSION
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number bump`)
endif
	@echo Bumping the version number to $(VERSION)
	@echo $(VERSION) > VERSION
	@sed -i '' "s/\"version\": .*,/\"version\": \"$(VERSION)\",/" Bugsnag.podspec.json
	@sed -i '' "s/\"tag\": .*/\"tag\": \"v$(VERSION)\"/" Bugsnag.podspec.json
	@sed -i '' "s/NOTIFIER_VERSION = .*;/NOTIFIER_VERSION = @\"$(VERSION)\";/" Source/BugsnagNotifier.m
	@sed -i '' "s/## TBD/## $(VERSION) ($(shell date '+%Y-%m-%d'))/" CHANGELOG.md

prerelease: bump ## Generates a PR for the $VERSION release
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number prerelease`)
endif
	@git checkout -b release-v$(VERSION)
	@git add Source/BugsnagNotifier.m Bugsnag.podspec.json VERSION CHANGELOG.md
	@git commit -m "Release v$(VERSION)"
	@git push origin release-v$(VERSION)
	@hub pull-request -m "Release v$(VERSION)" --browse

release: ## Releases the current master branch as $VERSION
	@git fetch origin
ifneq ($(shell git rev-parse --abbrev-ref HEAD),master) # Check the current branch name
	@git checkout master
	@git rebase origin/master
endif
ifneq ($(shell git diff origin/master..master),)
	$(error you have unpushed commits on the master branch)
endif
	@git tag v$(PRESET_VERSION)
	@git push origin v$(PRESET_VERSION)
	# Prep GitHub release
	# We could technically do a `hub release` here but a verification step
	# before it goes live always seems like a good thing
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?tag=v$(PRESET_VERSION)&body='$$(awk 'start && /^## /{exit;};/^## /{start=1;next};start' CHANGELOG.md | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g')
	# Workaround for CocoaPods/CocoaPods#8000
	@EXPANDED_CODE_SIGN_IDENTITY="" EXPANDED_CODE_SIGN_IDENTITY_NAME="" EXPANDED_PROVISIONING_PROFILE="" pod trunk push --allow-warnings

clean: ## Clean build artifacts
	@$(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -rf build

test: ## Run unit tests
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

e2e: ## Run integration tests
	@bundle exec maze-runner

archive: build/Bugsnag-$(PLATFORM)-$(PRESET_VERSION).zip

doc: ## Generate html documentation
	@headerdoc2html -N -o docs $(shell ruby -e "require 'json'; print Dir.glob(JSON.parse(File.read('Bugsnag.podspec.json'))['public_header_files']).join(' ')") -j
	@gatherheaderdoc docs
	@mv docs/masterTOC.html docs/index.html

help: ## Show help text
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
