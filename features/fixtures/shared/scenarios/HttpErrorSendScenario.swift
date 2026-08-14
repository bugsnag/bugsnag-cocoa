//
//  HttpErrorSendScenario.swift
//  macOSTestApp
//
//  Created by Daria Bialobrzeska on 10/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

import Foundation

@available(iOS 10.0, macOS 10.12, *)
class HttpErrorSendScenario : Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false;

        let pluginConfig = BugsnagNetworkRequestFailuresConfiguration()
        pluginConfig.addHttpErrorCodes([400, 401, 403, 444])
        let plugin = BugsnagNetworkRequestPlugin.initWithConfiguration(configuration: pluginConfig, enableNetworkBreadcrumbs: true)
        config.add(plugin)

        config.addOnBreadcrumb {
            let url = $0.metadata["url"] as? String ?? ""
            return url.hasPrefix(self.fixtureConfig.mazeRunnerURL.absoluteString) && url.contains("/reflect")
        }
    }

    override func run() {
        query(string: "/reflect/?status=444&password=T0p5ecr3t")
        query(string: "/reflect/?status=500")
    }

    func query(string: String) {
        let url = URL(string: fixtureConfig.mazeRunnerURL.absoluteString + string)!
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
    }
}
