//
//  swift_watchosApp.swift
//  swift-watchos WatchKit Extension
//
//  Created by Karl Stenerud on 13.04.22.
//

import SwiftUI
import Bugsnag

@main
struct swift_watchosApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
    
    init() {
        Bugsnag.start()
    }
}
