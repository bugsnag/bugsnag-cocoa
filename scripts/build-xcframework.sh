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

# Base name of the .xcodeproj directory
PROJECT_NAME=Bugsnag

# Targets that are suffixed with the platform (e.g. XYZ-iOS, XYZ-macOS etc)
NAMESPACED_TARGETS=( "Bugsnag" )

# Targets that are not namespaced
GENERIC_TARGETS=(  )

# Platforms we are building for: iOS, macOS, tvOS, watchOS (in future: visionOS)
PLATFORMS=( "iOS" "macOS" "tvOS" "watchOS" )



# -------------------------------------------------------------------
# Script
# -------------------------------------------------------------------

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR=$( cd -- "$( dirname -- "${SCRIPT_DIR}" )" &> /dev/null && pwd )
XCFW_DIR="${PROJECT_DIR}/build/xcframeworks"
INTERMEDIATES_DIR="${XCFW_DIR}/intermediates"
PRODUCTS_DIR="${XCFW_DIR}/products"

rm -rf "${XCFW_DIR}"
mkdir -p "${INTERMEDIATES_DIR}"
mkdir -p "${PRODUCTS_DIR}"

##
# Build a target. This function tries to sort out whether the target is namespaced or not
# (i.e. if it's named XYZ or XYZ-iOS) so that it produces a consistently named output file
# (such as XYZ-iOS.framework, XYZ-iOS-simulator.framework).
#
# Args:
#   1: Name of compilation target
#   2: Name of platform to build for (iOS, macOS, etc)
#
# Return: A set of commandline argumets for the final framework build.
##
build_target() {
    target=$1
    platform=$2

    framework_name=${target}
    if [[ ${framework_name} == *${platform} ]]; then
        # If our target is named "XYZ-iOS", remove the "-iOS" part from the framework name
        framework_name="${framework_name%-${platform}}"
    fi

    destination="generic/platform=${platform}"
    archive_path="${INTERMEDIATES_DIR}/${target}"
    if [[ ${archive_path} != *${platform} ]]; then
        # Make sure our archive path is namespaced with the platform
        archive_path="${archive_path}-${platform}"
    fi
    # Note: Redirecting xcodebuild's stdout to stderr because we need stdout for ourselves.
    xcodebuild archive -project ${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj \
                       -scheme ${target} \
                       -configuration Release \
                       SKIP_INSTALL=NO \
                       BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
                       -destination "${destination}" \
                       -archivePath "${archive_path}" 1>&2
    echo "-archive ${archive_path}.xcarchive -framework ${framework_name}.framework"

    if [ "${platform}" != "macOS" ]; then
        # For non-macos targrets, build for the simulator as well.
        destination="${destination} Simulator"
        archive_path="${archive_path}-simulator"
        xcodebuild archive -project ${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj \
                           -scheme ${target} \
                           -configuration Release \
                           SKIP_INSTALL=NO \
                           BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
                           -destination "${destination}" \
                           -archivePath "${archive_path}" 1>&2
        echo "-archive ${archive_path}.xcarchive -framework ${framework_name}.framework"
    fi
}

if [[ ${#NAMESPACED_TARGETS[@]} -gt 0 ]]; then
    for target in "${NAMESPACED_TARGETS[@]}"; do
        xcframework_args=""
        for platform in "${PLATFORMS[@]}"; do
            new_args=$( build_target ${target}-${platform} ${platform} )
            xcframework_args="${xcframework_args} ${new_args}"
        done
        xcodebuild -create-xcframework ${xcframework_args} -output "${PRODUCTS_DIR}/${target}.xcframework"
    done
fi

if [[ ${#GENERIC_TARGETS[@]} -gt 0 ]]; then
    for target in "${GENERIC_TARGETS[@]}"; do
        xcframework_args=""
        for platform in "${PLATFORMS[@]}"; do
            new_args=$( build_target ${target} ${platform} )
            xcframework_args="${xcframework_args} ${new_args}"
        done
        xcodebuild -create-xcframework ${xcframework_args} -output "${PRODUCTS_DIR}/${target}.xcframework"
    done
fi

echo
echo "** build-frameworks.sh: script completed successfully **"
