#!/usr/bin/env bash
#
# Xcode 27 CI only: adds a UIScene manifest to an iOS app's Info.plist.
#
# Apps built with the iOS 27 SDK must adopt the UIScene life cycle or they fail
# to launch. The manifest is NOT committed to Info.plist because Xcode 26 builds
# run on iOS 13-16, where the scene life cycle changes when app and device state
# becomes known: it broke the barebone tests' orientation check and made the
# iOS 15 unit tests hang.
#
# Usage: xcode27-enable-uiscene.sh [plist] [scene delegate class] [storyboard]
#   No arguments: the iOS test fixture (SceneDelegate in iOSTestApp/AppDelegate.swift).
#   Unit test host: xcode27-enable-uiscene.sh Tests/TestHost-iOS/Info.plist SceneDelegate ""
#     (SceneDelegate in Tests/TestHost-iOS/AppDelegate.m creates its own window).
#
# The CI checkout discards this change on the next job.

set -euo pipefail

PLIST="${1:-features/fixtures/ios/iOSTestApp/Info.plist}"
DELEGATE="${2:-\$(PRODUCT_MODULE_NAME).SceneDelegate}"
STORYBOARD="${3-Main}"

if /usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest" "$PLIST" >/dev/null 2>&1; then
  echo "UIApplicationSceneManifest already present in $PLIST"
  exit 0
fi

CONFIG=":UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0"

/usr/libexec/PlistBuddy \
  -c "Add :UIApplicationSceneManifest dict" \
  -c "Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations dict" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication array" \
  -c "Add $CONFIG dict" \
  -c "Add $CONFIG:UISceneConfigurationName string 'Default Configuration'" \
  -c "Add $CONFIG:UISceneDelegateClassName string '$DELEGATE'" \
  "$PLIST"

if [[ -n "$STORYBOARD" ]]; then
  /usr/libexec/PlistBuddy -c "Add $CONFIG:UISceneStoryboardFile string $STORYBOARD" "$PLIST"
fi

echo "Added UIApplicationSceneManifest to $PLIST:"
/usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest" "$PLIST"
