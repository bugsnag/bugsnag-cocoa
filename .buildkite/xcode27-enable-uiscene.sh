#!/usr/bin/env bash
#
# Xcode 27 CI only: adds a UIScene manifest to the iOS test fixture's Info.plist.
#
# Apps built with the iOS 27 SDK must adopt the UIScene life cycle or they fail
# to launch. The manifest is NOT committed to Info.plist because Xcode 26
# fixtures run on iOS 13-16, where the scene life cycle changes when the device
# orientation becomes known and breaks the barebone tests' orientation check.
#
# The SceneDelegate class it names lives in iOSTestApp/AppDelegate.swift.
# The CI checkout discards this change on the next job.

set -euo pipefail

PLIST="features/fixtures/ios/iOSTestApp/Info.plist"

if /usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest" "$PLIST" >/dev/null 2>&1; then
  echo "UIApplicationSceneManifest already present in $PLIST"
  exit 0
fi

/usr/libexec/PlistBuddy \
  -c "Add :UIApplicationSceneManifest dict" \
  -c "Add :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes bool false" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations dict" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication array" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0 dict" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneConfigurationName string 'Default Configuration'" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName string '\$(PRODUCT_MODULE_NAME).SceneDelegate'" \
  -c "Add :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneStoryboardFile string Main" \
  "$PLIST"

echo "Added UIApplicationSceneManifest to $PLIST:"
/usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest" "$PLIST"
