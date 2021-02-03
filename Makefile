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
DATA_PATH=DerivedData
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

.PHONY: all analyze archive bootstrap build build_carthage build_ios_static build_swift bump clean docs help infer prerelease release test test-fixtures

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

compile_commands.json:
	set -o pipefail && xcodebuild -project Bugsnag.xcodeproj -configuration Release -scheme Bugsnag-iOS \
		-destination generic/platform=iOS \
		-derivedDataPath $(DATA_PATH) \
		build VALID_ARCHS=arm64 RUN_CLANG_STATIC_ANALYZER=NO | \
		bundle exec xcpretty -r json-compilation-database -o compile_commands.json

#--------------------------------------------------------------------------
# Static Analysis
#--------------------------------------------------------------------------

analyze: ## Run Xcode's analyzer on the build and fail if issues found
	@xcodebuild $(BUILD_FLAGS) -quiet $(BUILD_ONLY_FLAGS) analyze \
		CLANG_ANALYZER_OUTPUT=html \
		CLANG_ANALYZER_OUTPUT_DIR=$(DATA_PATH)/analyzer \
		&& [[ -z `find $(DATA_PATH)/analyzer -name "*.html"` ]]

INFER=$(HOME)/Library/Caches/infer-osx-v1.0.0/bin/infer

infer: $(INFER) compile_commands.json ## Run the "Infer" static analysis tool
	@$(INFER) run --report-console-limit 100 --compilation-database compile_commands.json

$(INFER):
	@echo Downloading Infer...
	@curl -L https://github.com/facebook/infer/releases/download/v1.0.0/infer-osx-v1.0.0.tar.xz | tar -x -C $(HOME)/Library/Caches

OCLINT=$(HOME)/Library/Caches/oclint-20.11/bin/oclint-json-compilation-database

oclint: $(OCLINT) compile_commands.json ## Run the "OCLint" static analysis tool
ifeq ($(CI), true)
	@$(OCLINT) -- --report-type=json -o=oclint.json || echo "OCLint exited with an error status"
else
	@$(OCLINT) || echo "OCLint exited with an error status"
endif

$(OCLINT):
	@echo Downloading oclint...
	@curl -L https://github.com/oclint/oclint/releases/download/v20.11/oclint-20.11-llvm-11.0.0-x86_64-darwin-macos-big-sur-11.0.1-xcode-12.2.tar.gz | tar -x -C $(HOME)/Library/Caches

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
	@sed -i '' -E "s/[0-9]+.[0-9]+.[0-9]+/$(VERSION)/g" .jazzy.yaml
	@agvtool new-marketing-version $(VERSION)

prerelease: bump ## Generates a PR for the $VERSION release
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number prerelease`)
endif
	@git checkout -b release-v$(VERSION)
	@git add Bugsnag/Payload/BugsnagNotifier.m Bugsnag.podspec.json VERSION CHANGELOG.md Framework/Info.plist Tests/Info.plist .jazzy.yaml
	@git diff --exit-code || (echo "you have unstaged changes - Makefile may need updating to `git add` some more files"; exit 1)
	@git commit -m "Release v$(VERSION)"
	@git push origin release-v$(VERSION)
	@hub pull-request -m "Release v$(VERSION)" --browse

#--------------------------------------------------------------------------
# Miscellaneous
#--------------------------------------------------------------------------

clean: ## Clean build artifacts
	@rm -rf .build $(DATA_PATH) compile_commands.json docs xcodebuild.log
	@set -x && $(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)

archive: build/Bugsnag-$(PLATFORM)-$(PRESET_VERSION).zip

docs: ## Generate or update HTML documentation
	@rm -rf docs/*
	@bundle exec jazzy
ifneq ($(wildcard docs/.git),)
	@cd docs && git add --all . && git commit -m "Docs update for $(PRESET_VERSION) release"
endif

help: ## Show help text
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
