import UIKit
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logInfo("==== IOS FIXTURE DID FINISH LAUNCHING ====");
        return true
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {
        logInfo("App has been opened via its registered URL");
        return true
    }
}

// Apps built with the iOS 27 SDK must adopt the UIScene life cycle or they fail to launch.
// Only used by Xcode 27 CI builds: .buildkite/xcode27-enable-uiscene.sh adds the scene
// manifest that names this class to Info.plist. The window and root view controller come
// from the storyboard named in that manifest.
@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        logInfo("App has been opened via its registered URL");
    }
}
