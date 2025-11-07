//
//  CaptureOptionsScenario.swift
//  iOSTestApp
//
//  Created by Daria Bialobrzeska on 04/11/2025.
//  Copyright © 2025 Bugsnag. All rights reserved.
//

import Foundation

class CaptureOptionsScenario: Scenario {
    var errorOptions: BugsnagErrorOptions?

    override func configure() {
        super.configure()
        config.launchDurationMillis = 0
        config.maxStringValueLength = 100
#if !os(watchOS)
        config.sendThreads = .always
#endif
        config.setUser("foobar", withEmail: "foobar@example.com", andName: "Foo Bar")
        config.addMetadata(["msg": "My message"], section: "custom")
        config.addMetadata(["msg2": "My message2"], section: "custom2")
        config.addFeatureFlag(name: "Testing", variant: "e2e")
        errorOptions = BugsnagErrorOptions()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb(withMessage: "CaptureOptionsScenario breadcrumb")
    }

    @objc func notify_manual() {
        Bugsnag.notify(NSException(name: .rangeException,
                                   reason: "Something is out of range"),
                       options:self.errorOptions)
    }

    @objc func disable_breadcrumb() {
        self.errorOptions?.capture?.breadcrumbs = false
    }

    @objc func disable_feature_flags() {
        self.errorOptions?.capture?.featureFlags = false
    }

    @objc func disable_stacktrace() {
        self.errorOptions?.capture?.stacktrace = false
    }

    @objc func disable_threads() {
        self.errorOptions?.capture?.threads = false
    }

    @objc func disable_user() {
        self.errorOptions?.capture?.user = false
    }

    @objc func metadata_empty() {
        self.errorOptions?.capture?.metadata = []
    }

    @objc func disable_specific_section_metadata2() {
        self.errorOptions?.capture?.metadata = ["custom"]
    }
}
