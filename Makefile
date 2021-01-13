#--------------------------------------------------------------------------
# Bugsnag Makefile
#
# This file contains rules for building, testing and releasing the Bugsnag
# Cocoa crash reporting framework.  It is intended to be used by Bugsnag
# developers and automated systems.  It is NOT intended for use by end-users
# wishing to use the framework.  For that please deploy Bugsnag in your
# application using one of the supported methods: Cocoapods, Carthage etc.
#
#--------------------------------------------------------------------------

# Set up the build environment based on environment variables, or defaults
# if the environment has not been set.

PLATFORM?=iOS
OS?=latest
TEST_CONFIGURATION?=Debug
DATA_PATH=build/build-$(PLATFORM)
BUILD_FLAGS=-project Bugsnag.xcodeproj -scheme Bugsnag-$(PLATFORM) -derivedDataPath $(DATA_PATH)

ifeq ($(PLATFORM),macOS)
 SDK?=macosx
 RELEASE_DIR=Release
 BUILD_ONLY_FLAGS=-sdk $(SDK) CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
else
 ifeq ($(PLATFORM),tvOS)
  SDK?=appletvsimulator
  DESTINATION?=platform=tvOS Simulator,name=Apple TV,OS=$(OS)
 else
  SDK?=iphonesimulator
  DEVICE?=iPhone 8
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

# The default rule.

all: build

# A phony target is one that is not really the name of a file; rather it is just a name for a recipe to be executed when you make an explicit request.
# There are two reasons to use a phony target: to avoid a conflict with a file of the same name, and to improve performance.

.PHONY: all analyze archive bootstrap build build_carthage build_ios_static build_swift bump clean doc help infer prerelease release test test-fixtures update-docs

#--------------------------------------------------------------------------
# Build
#--------------------------------------------------------------------------

build: ## Build the library
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) build $(FORMATTER)

# Generated framework package for Bugsnag for either iOS or macOS
build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework:
	@xcodebuild $(BUILD_FLAGS) \
		-configuration Release \
		-derivedDataPath build clean build $(FORMATTER)

# Compressed bundle for release version of Bugsnag framework
build/Bugsnag-%-$(PRESET_VERSION).zip: build/Build/Products/$(RELEASE_DIR)/Bugsnag.framework
	@cd build/Build/Products/$(RELEASE_DIR); \
		zip --symlinks -rq ../../../Bugsnag-$*-$(PRESET_VERSION).zip Bugsnag.framework

bootstrap: ## Install development dependencies
	@bundle install

build_ios_static: ## Build the static library target
	$(XCODEBUILD) -project Bugsnag.xcodeproj -scheme BugsnagStatic

build_carthage: ## Build the latest pushed commit with Carthage
	@mkdir -p features/fixtures/carthage-proj
	@echo 'git "file://$(shell pwd)" "'$(shell git rev-parse HEAD)'"' > features/fixtures/carthage-proj/Cartfile
	@cd features/fixtures/carthage-proj && \
	 carthage update --platform ios && \
	 carthage update --platform macos && \
	 carthage update --platform tvos

build_swift: ## Build with Swift Package Manager
	@swift build

#--------------------------------------------------------------------------
# Static Analysis
#--------------------------------------------------------------------------

analyze: ## Run Xcode's analyzer on the build and fail if issues found
	@xcodebuild $(BUILD_FLAGS) -quiet $(BUILD_ONLY_FLAGS) analyze \
		CLANG_ANALYZER_OUTPUT=html \
		CLANG_ANALYZER_OUTPUT_DIR=$(DATA_PATH)/analyzer \
		&& [[ -z `find $(DATA_PATH)/analyzer -name "*.html"` ]]

INFER=$(HOME)/Library/Caches/infer-osx-v1.0.0/bin/infer

infer: $(INFER) ## Run the "Infer" static analyzer
	@$(INFER) run --report-console-limit 100 -- xcodebuild -quiet \
		$(BUILD_FLAGS) -configuration Release -destination generic/platform=iOS \
		clean build VALID_ARCHS=arm64

$(INFER):
	@echo Downloading Infer...
	@curl -L https://github.com/facebook/infer/releases/download/v1.0.0/infer-osx-v1.0.0.tar.xz | tar -x -C $(HOME)/Library/Caches

#--------------------------------------------------------------------------
# Testing
#--------------------------------------------------------------------------

test: ## Run unit tests
	@sw_vers
	@$(XCODEBUILD) -version
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

test-fixtures: ## Build the end-to-end test fixture
	@./features/scripts/export_ios_app.sh
	@./features/scripts/export_mac_app.sh

#--------------------------------------------------------------------------
# Release
#
# See CONTRIBUTING.md for step-by-step release instructions.
#--------------------------------------------------------------------------

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
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?title=v$(PRESET_VERSION)&tag=v$(PRESET_VERSION)&body='$$(awk 'start && /^## /{exit;};/^## /{start=1;next};start' CHANGELOG.md | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g')
	# Workaround for CocoaPods/CocoaPods#8000
	@EXPANDED_CODE_SIGN_IDENTITY="" EXPANDED_CODE_SIGN_IDENTITY_NAME="" EXPANDED_PROVISIONING_PROFILE="" pod trunk push --allow-warnings

bump: ## Bump the version numbers to $VERSION
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number bump`)
endif
	@echo Bumping the version number to $(VERSION)
	@echo $(VERSION) > VERSION
	@sed -i '' "s/\"version\": .*,/\"version\": \"$(VERSION)\",/" Bugsnag.podspec.json
	@sed -i '' "s/\"tag\": .*/\"tag\": \"v$(VERSION)\"/" Bugsnag.podspec.json
	@sed -i '' "s/self.version = .*;/self.version = @\"$(VERSION)\";/" Bugsnag/Payload/BugsnagNotifier.m
	@sed -i '' "s/## TBD/## $(VERSION) ($(shell date '+%Y-%m-%d'))/" CHANGELOG.md
	@agvtool new-marketing-version $(VERSION)

prerelease: bump ## Generates a PR for the $VERSION release
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number prerelease`)
endif
	@git checkout -b release-v$(VERSION)
	@git add Bugsnag/Payload/BugsnagNotifier.m Bugsnag.podspec.json VERSION CHANGELOG.md Framework/Info.plist Tests/Info.plist
	@git commit -m "Release v$(VERSION)"
	@git push origin release-v$(VERSION)
	@hub pull-request -m "Release v$(VERSION)" --browse

#--------------------------------------------------------------------------
# Miscellaneous
#--------------------------------------------------------------------------

clean: ## Clean build artifacts
	@set -x && $(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)
	@rm -rf build-$(PLATFORM)
	@rm -rf .build

archive: build/Bugsnag-$(PLATFORM)-$(PRESET_VERSION).zip

doc: ## Generate html documentation
	@headerdoc2html -N -o docs $(shell ruby -e "require 'json'; print Dir.glob(JSON.parse(File.read('Bugsnag.podspec.json'))['public_header_files']).join(' ')") -j
	@gatherheaderdoc docs
	@mv docs/masterTOC.html docs/index.html

update-docs: ## Update and upload docs to Github
ifeq ($(BUILDKITE),)
	@$(error Docs deployment is handled by CI, and shouldn't be run locally)
endif
ifeq ($(BUILDKITE_TAG),)
	@$(error Docs deployments should only occur on a tagged release)
endif
	@git clone --single-branch --branch=gh-pages git@github.com:bugsnag/bugsnag-cocoa.git docs
	@make doc
	@cd docs
	@git add .
	@git commit -m "Docs update for $BUILDKITE_TAG release"
	@git push --force-with-lease

help: ## Show help text
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
