//
//  BugsnagWrapper.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 23/02/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

class BugsnagWrapper : Bugsnag {

    static var plistNotifyEndpoint: String = "";
    static var plistSessionsEndpoint: String = "";

    override class func start(with configuration: BugsnagConfiguration) -> BugsnagClient {

        // Store the endpoint values read from the plist
        plistNotifyEndpoint = configuration.endpoints.notify;
        plistSessionsEndpoint = configuration.endpoints.sessions;
        
        NSLog("Plist notify endpoint: %@", plistNotifyEndpoint);
        NSLog("Plist sessions endpoint: %@", plistSessionsEndpoint);

        if (plistNotifyEndpoint != "http://example.com/notify"
            || plistSessionsEndpoint != "http://example.com/sessions") {

            fatalError("Endpoint configuration read from plist is not as expected");
        }
        
        // Overwrite the configuration endpoints
        configuration.endpoints.notify = String(format: "%@/notify", Scenario.baseMazeAddress);
        configuration.endpoints.sessions = String(format: "%@/sessions", Scenario.baseMazeAddress);
        
        return Bugsnag.start(with: configuration);
    }
}
