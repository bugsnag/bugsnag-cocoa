//
//  HttpErrorSendPostScenario.swift
//  macOSTestApp
//
//  Created by Daria Bialobrzeska on 12/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

import Foundation

@available(iOS 10.0, macOS 10.12, *)
class HttpErrorSendPostScenario : Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false;

        let pluginConfig = BugsnagNetworkRequestFailuresConfiguration()
        pluginConfig.addHttpErrorCodes([400, 401, 403, 444])
        pluginConfig.maxRequestBodyCapture = 20
        let plugin = BugsnagNetworkRequestPlugin.initWithConfiguration(configuration: pluginConfig, enableNetworkBreadcrumbs: true)
        config.add(plugin)

        config.addOnBreadcrumb {
            let url = $0.metadata["url"] as? String ?? ""
            return url.hasPrefix(self.fixtureConfig.mazeRunnerURL.absoluteString) && url.contains("/reflect")
        }
    }

    override func run() {
        query(string: "/reflect", code: "400")
        query(string: "/reflect", code: "500")
    }

    func query(string: String, code: String) {
        let url = URL(string: fixtureConfig.mazeRunnerURL.absoluteString + string)!
        let semaphore = DispatchSemaphore(value: 0)

        let request = NSMutableURLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        let mapData = ["status": code, "myfillerdata": "1234567890123456789012345678901234567890"]
        let postData = try? JSONSerialization.data(withJSONObject: mapData, options: [])
        request.httpBody = postData
        request.url = url

        let task = URLSession.shared.dataTask(with: request as URLRequest) {(data, response, error) in
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()
    }
}
