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
XCODEBUILD_EXTRA_ARGS?=
DATA_PATH=DerivedData
BUILD_FLAGS=-workspace Bugsnag.xcworkspace -scheme Bugsnag-$(PLATFORM) -derivedDataPath $(DATA_PATH) $(XCODEBUILD_EXTRA_ARGS)

ifeq ($(PLATFORM),macOS)
 SDK?=macosx
 RELEASE_DIR=Release
 BUILD_ONLY_FLAGS=-sdk $(SDK) CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
else
 ifeq ($(PLATFORM),tvOS)
  SDK?=appletvsimulator
  DESTINATION?=platform=tvOS Simulator,name=Apple TV,OS=$(OS)
 else
  ifeq ($(PLATFORM),iOS)
   SDK?=iphonesimulator
   ifeq ($(shell expr $(OS) \>= 17.0), 1)
	DEVICE?=iPhone 14
   else
	DEVICE?=iPhone 8
   endif
   DESTINATION?=platform=iOS Simulator,name=$(DEVICE),OS=$(OS)
   RELEASE_DIR=Release-iphoneos
  else
   SDK?=watchsimulator
#   Due to the inconsistency of device names as a result of running; xcodebuild -downloadAllPlatforms, this dynamically selects the watchOS device.
   DEVICE?=$(shell xcrun simctl list --json | jq -r '.devices."com.apple.CoreSimulator.SimRuntime.watchOS-8-5"[] | select(.name | test("Apple Watch Series 5 .+ ?40mm ?")) | .name')
   DESTINATION?=platform=watchOS Simulator,name=$(DEVICE),OS=$(OS)
   RELEASE_DIR=Release-watchos
  endif
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
	@./scripts/build-carthage.sh

build_xcframework: ## Build as a multiplatform xcframework
	@./scripts/build-xcframework.sh

build_swift: ## Build with Swift Package Manager
	@swift build

compile_commands.json:
	set -o pipefail && xcodebuild -project Bugsnag.xcodeproj -configuration Release -scheme Bugsnag-iOS \
		-destination generic/platform=iOS \
		-derivedDataPath $(DATA_PATH) \
		build VALID_ARCHS=arm64 RUN_CLANG_STATIC_ANALYZER=NO | \
		xcpretty -r json-compilation-database -o compile_commands.json

#--------------------------------------------------------------------------
# Static Analysis
#--------------------------------------------------------------------------

analyze: ## Run Xcode's analyzer on the build and fail if issues found
	@xcodebuild $(BUILD_FLAGS) -quiet $(BUILD_ONLY_FLAGS) analyze \
		CLANG_ANALYZER_OUTPUT=html \
		CLANG_ANALYZER_OUTPUT_DIR=$(DATA_PATH)/analyzer \
		&& [[ -z `find $(DATA_PATH)/analyzer -name "*.html"` ]]

infer: compile_commands.json ## Run the "Infer" static analysis tool
	@infer run --report-console-limit 100 --compilation-database compile_commands.json

oclint: compile_commands.json ## Run the "OCLint" static analysis tool
ifeq ($(CI), true)
	@oclint-json-compilation-database -- --report-type=json -o=oclint.json || echo "OCLint exited with an error status"
else
	@oclint-json-compilation-database || echo "OCLint exited with an error status"
endif

#--------------------------------------------------------------------------
# Testing
#--------------------------------------------------------------------------

test: ## Run unit tests
	@sw_vers
	@$(XCODEBUILD) -version
	@$(XCODEBUILD) $(BUILD_FLAGS) $(BUILD_ONLY_FLAGS) test $(FORMATTER)

test-fixtures: ## Build the end-to-end test fixture
	@./features/scripts/export_ios_app.sh Release
	@./features/scripts/export_ios_app.sh Debug
	@./features/scripts/export_mac_app.sh Release
	@./features/scripts/export_mac_app.sh Debug

xcframework-test-fixtures: ## Build the xcframework end-to-end test fixture
	@./features/scripts/export_xcframework_ios_app.sh
	@./features/scripts/export_xcframework_mac_app.sh

e2e_ios_local:
	@./features/scripts/export_ios_app.sh
	bundle exec maze-runner --app=features/fixtures/ios/output/iOSTestApp.ipa --farm=local --os=ios --apple-team-id=7W9PZ27Y5F --udid="$(shell idevice_id -l)" $(FEATURES)

e2e_macos:
	./features/scripts/export_mac_app.sh
	bundle exec maze-runner --os=macOS $(FEATURES)
ifeq ($(ENABLE_CODE_COVERAGE), YES)
	xcrun llvm-profdata merge -sparse *.profraw -o default.profdata
	rm -rf *.profraw
	xcrun llvm-cov show -format html -output-dir coverage -instr-profile default.profdata features/fixtures/macos/output/macOSTestApp.app/Contents/Frameworks/Bugsnag.framework/Versions/A/Bugsnag -arch $(shell uname -m)
	rm default.profdata
endif

.PHONY: e2e_watchos
e2e_watchos: features/fixtures/watchos/Podfile.lock features/fixtures/shared/scenarios/watchos_maze_host.h
	open --background features/fixtures/watchos/watchOSTestApp.xcworkspace
ifneq ($(FEATURES),)
	bundle exec maze-runner --os=watchos $(FEATURES)
else
	bundle exec maze-runner --os=watchos --tags @watchos
endif

features/fixtures/watchos/Podfile.lock: features/fixtures/watchos/Podfile
	cd features/fixtures/watchos && pod install

.PHONY: features/fixtures/shared/scenarios/watchos_maze_host.h
features/fixtures/shared/scenarios/watchos_maze_host.h:
	printf '#define WATCHOS_MAZE_HOST ' > $@
	ruby -r socket -e 'p Socket.ip_address_list.select{ |a| a.ipv4_private? }[0].ip_address' >> $@

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
	# Swift Package Manager prefers tags to be unprefixed package versions
	@git tag $(PRESET_VERSION)
	@git push origin v$(PRESET_VERSION) $(PRESET_VERSION)
	@git checkout next
	@git rebase origin/next
	@git merge master
	@git push origin next
	# Prep GitHub release
	# We could technically do a `hub release` here but a verification step
	# before it goes live always seems like a good thing
	@open 'https://github.com/bugsnag/bugsnag-cocoa/releases/new?title=v$(PRESET_VERSION)&tag=v$(PRESET_VERSION)&body='$$(awk 'start && /^## /{exit;};/^## /{start=1;next};start' CHANGELOG.md | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g')
	# Workaround for CocoaPods/CocoaPods#8000
	@EXPANDED_CODE_SIGN_IDENTITY="" EXPANDED_CODE_SIGN_IDENTITY_NAME="" EXPANDED_PROVISIONING_PROFILE="" pod trunk push --allow-warnings Bugsnag.podspec.json
	@EXPANDED_CODE_SIGN_IDENTITY="" EXPANDED_CODE_SIGN_IDENTITY_NAME="" EXPANDED_PROVISIONING_PROFILE="" pod trunk push --allow-warnings --synchronous BugsnagNetworkRequestPlugin.podspec.json

bump: ## Bump the version numbers to $VERSION
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number bump`)
endif
	@echo Bumping the version number to $(VERSION)
	@echo $(VERSION) > VERSION
	@sed -i '' "s/\"version\": .*,/\"version\": \"$(VERSION)\",/" Bugsnag.podspec.json
	@sed -i '' "s/\"version\": .*,/\"version\": \"$(VERSION)\",/" BugsnagNetworkRequestPlugin.podspec.json
	@sed -i '' "s/\"tag\": .*/\"tag\": \"v$(VERSION)\"/" Bugsnag.podspec.json
	@sed -i '' "s/\"tag\": .*/\"tag\": \"v$(VERSION)\"/" BugsnagNetworkRequestPlugin.podspec.json
	@sed -i '' -E "s/\/bugsnag-cocoa\/v[0-9]+\.[0-9]+\.[0-9]+\//\/bugsnag-cocoa\/v$(VERSION)\//" BugsnagNetworkRequestPlugin.podspec.json
	@sed -i '' "s/_version = @\".*\";/_version = @\"$(VERSION)\";/" Bugsnag/Payload/BugsnagNotifier.m
	@sed -i '' "s/## TBD/## $(VERSION) ($(shell date '+%Y-%m-%d'))/" CHANGELOG.md
	@sed -i '' -E "s/[0-9]+.[0-9]+.[0-9]+/$(VERSION)/g" .jazzy.yaml
	@agvtool new-marketing-version $(VERSION)

prerelease: bump ## Generates a PR for the $VERSION release
ifeq ($(VERSION),)
	@$(error VERSION is not defined. Run with `make VERSION=number prerelease`)
endif
	@git checkout -b release-v$(VERSION)
	@git add Bugsnag/Payload/BugsnagNotifier.m Bugsnag.podspec.json BugsnagNetworkRequestPlugin.podspec.json VERSION CHANGELOG.md Framework/Info.plist Tests/BugsnagTests/Info.plist Tests/TestHost-iOS/Info.plist .jazzy.yaml
	@git diff --exit-code || (echo "you have unstaged changes - Makefile may need updating to `git add` some more files"; exit 1)
	@git commit -m "Release v$(VERSION)"
	@git push origin release-v$(VERSION)
	@open "https://github.com/bugsnag/bugsnag-cocoa/compare/master...release-v$(VERSION)?expand=1&title=Release%20v$(VERSION)&body="$$(awk 'start && /^## /{exit;};/^## /{start=1;next};start' CHANGELOG.md | hexdump -v -e '/1 "%02x"' | sed 's/\(..\)/%\1/g')

#--------------------------------------------------------------------------
# Miscellaneous
#--------------------------------------------------------------------------

clean: ## Clean build artifacts
	@rm -rf .build $(DATA_PATH) compile_commands.json docs xcodebuild.log
	@set -x && $(XCODEBUILD) $(BUILD_FLAGS) clean $(FORMATTER)

archive: build/Bugsnag-$(PLATFORM)-$(PRESET_VERSION).zip

docs: ## Generate or update HTML documentation
	@rm -rf docs/*
	@jazzy
ifneq ($(wildcard docs/.git),)
	@cd docs && git add --all . && git commit -m "Docs update for $(PRESET_VERSION) release"
endif

help: ## Show help text
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
