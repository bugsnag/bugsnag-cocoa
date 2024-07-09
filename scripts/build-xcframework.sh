#!/usr/bin/env bash
#
# Written by: Karl Stenerud
#
# Script to build all platforms, architectures, and simulators into a single xcframework per target.
#
# See https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
#

set -e -u -o pipefail



# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------

# Framework:                The base name we want to give our xcframework.
# Project / Workspace Path: Local path to the .xcodeproj or .xcworkspace we want to load from
# Scheme:                   The base name of the scheme to build with (minus any "-iOS" type suffix)
# Namespaced:               If TRUE, the schemes to load all have an ("-iOS", "-macOS") style namespaced suffix.
TARGETS=(
#   [Framework]                     [Project/WS Path]      [Scheme]                       [NAMESPACED]
    "Bugsnag                        Bugsnag.xcworkspace    Bugsnag                        TRUE"
    "BugsnagNetworkRequestPlugin    Bugsnag.xcworkspace    BugsnagNetworkRequestPlugin    TRUE"
)

# Platforms we are building for
PLATFORMS=( "iOS" "macOS" "tvOS" "watchOS" )



# -------------------------------------------------------------------
# Script
# -------------------------------------------------------------------

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR=$( cd -- "$( dirname -- "${SCRIPT_DIR}" )" &> /dev/null && pwd )
XCFW_DIR="${PROJECT_DIR}/build/xcframeworks"
INTERMEDIATES_DIR="${XCFW_DIR}/intermediates"
PRODUCTS_DIR="${XCFW_DIR}/products"

##
# Build a framework.
#
# Args:
#   1: The base name of the framework to produce
#   2: Path to the project or workspace file (relative to the project root)
#   3: The scheme to build
#   4: The platform to build for (iOS, macOS, etc)
#
# Return: A set of commandline argumets for the final framework build.
##
build_framework() {
    local framework_basename=$1
    local proj_ws_path=$2
    local scheme=$3
    local platform=$4

    local destination="generic/platform=${platform}"
    local archive_path="${INTERMEDIATES_DIR}/${framework_basename}-${platform}"
    local proj_ws_arg="-project ${PROJECT_DIR}/${proj_ws_path}"
    if [[ $proj_ws_path == *xcworkspace ]]; then
        proj_ws_arg="-workspace ${PROJECT_DIR}/${proj_ws_path}"
    fi

    # Note: Redirecting xcodebuild's stdout to stderr because we need stdout for ourselves.
    xcodebuild archive $proj_ws_arg \
                       -scheme ${scheme} \
                       -configuration Release \
                       SKIP_INSTALL=NO \
                       BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
                       -destination "${destination}" \
                       -archivePath "${archive_path}" 1>&2
    echo "-archive ${archive_path}.xcarchive -framework ${framework_basename}.framework"

    if [ "${platform}" != "macOS" ]; then
        # For non-macos targrets, build for the simulator as well.
        destination="${destination} Simulator"
        archive_path="${archive_path}-simulator"
        xcodebuild archive $proj_ws_arg \
                           -scheme ${scheme} \
                           -configuration Release \
                           SKIP_INSTALL=NO \
                           BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
                           -destination "${destination}" \
                           -archivePath "${archive_path}" 1>&2
        echo "-archive ${archive_path}.xcarchive -framework ${framework_basename}.framework"
    fi
}

fixup_xcframework() {
    # Swift compiler bug: Having a class with the same name as the module breaks things.
    #
    # The dependent module including such a module will generate class definitions like this:
    #     "MyClass : MyModuleName.MyInterface {"
    # When it should generate:
    #     "MyClass : MyInterface {"
    #
    # So we search for this prefix and strip it out.
    #
    # https://developer.apple.com/forums/thread/123253

    local framework_basename="$1"
    local framework_path="${PRODUCTS_DIR}/${framework_basename}.xcframework"

    for target_record in "${TARGETS[@]}"; do
        local target_args=($target_record)
        local target_framework=${target_args[0]}

        find "$framework_path" -name "*.swiftinterface" -exec sed -i -e "s/$target_framework\\.//g" {} \;
    done
}

build_frameworks() {
    for target_record in "${TARGETS[@]}"; do
        local target_args=($target_record)
        local framework=${target_args[0]}
        local project=${target_args[1]}
        local scheme=${target_args[2]}
        local namespaced=${target_args[3]}

        echo "Building ${framework}.xcframework"
        local xcframework_args=""
        for platform in "${PLATFORMS[@]}"; do
            local current_scheme="$scheme"
            if [ "$namespaced" = "TRUE" ]; then
                current_scheme="${current_scheme}-${platform}"
            fi
            local added_args=$( build_framework ${framework} ${project} ${current_scheme} ${platform} )
            xcframework_args="${xcframework_args} ${added_args}"
        done
        xcodebuild -create-xcframework ${xcframework_args} -output "${PRODUCTS_DIR}/${framework}.xcframework"
        fixup_xcframework $framework
        pushd "${PRODUCTS_DIR}"
        zip --symlinks -rq "${framework}.xcframework.zip" "${framework}.xcframework"
        popd
    done
}

rm -rf "${XCFW_DIR}"
mkdir -p "${INTERMEDIATES_DIR}"
mkdir -p "${PRODUCTS_DIR}"

build_frameworks

echo
echo "** build-frameworks.sh: script completed successfully **"
