//
//  IsStartedScenario.swift
//  iOSTestApp
//
//  Created by Robert B on 03/03/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

@objc class InternalWorkingsScenario: Scenario {

    private let backupModePrefix = "backup_"
    private let unrelatedFilename = "backup-unrelated-marker.txt"

    override func configure() {
        super.configure()
        if modeContains("true") {
            config.fileBackupSupport = true
        } else if modeContains("false") {
            // Explicitly verify parity with omitted/default behavior.
            config.fileBackupSupport = false
        }
    }
    
    override func startBugsnag() {
        if modeContains("unrelated") {
            createUnrelatedFileMarker()
        }
        if modeContains("mixed") {
            corruptSubsetOfManagedPaths()
        }
        verifyBugsnagIsNotStarted()
        super.startBugsnag()
    }

    override func run() {
        if modeContains("crash") {
            prepareBackupStorage()
            fatalError("Backup metadata crash trigger")
        }
        verifyBugsnagIsStarted()
        reportStatusOk()
    }

    @objc func prepareBackupStorage() {
        Bugsnag.leaveBreadcrumb(withMessage: "backup-breadcrumb-\(Date().timeIntervalSince1970)")
        Bugsnag.addFeatureFlag(name: "backup-metadata-flag", variant: "v1")
        Bugsnag.startSession()
        Bugsnag.notifyError(NSError(domain: "InternalWorkingsScenario.backup.seed", code: 1))
    }

    @objc func exerciseBackupRewrites() {
        for index in 0..<3 {
            Bugsnag.leaveBreadcrumb(withMessage: "backup-rewrite-breadcrumb-\(index)")
        }
        Bugsnag.addFeatureFlag(name: "backup-rewrite-flag", variant: "a")
        Bugsnag.clearFeatureFlag(name: "backup-rewrite-flag")
        Bugsnag.addFeatureFlag(name: "backup-rewrite-flag", variant: "b")
        Bugsnag.pauseSession()
        Bugsnag.resumeSession()
        Bugsnag.notifyError(NSError(domain: "InternalWorkingsScenario.backup.rewrite", code: 2))
    }

    @objc func reportBackupMetadataSnapshot() {
        let expectedExcluded = !config.fileBackupSupport
        let snapshot = makeBackupSnapshot(expectedExcluded: expectedExcluded)
        Bugsnag.notifyError(NSError(domain: "InternalWorkingsScenario.backup.snapshot", code: 3)) { event in
            event.addMetadata(snapshot.summary, section: "backupSummary")
            event.addMetadata(snapshot.paths, section: "backupPaths")
            return true
        }
    }

    @objc func corruptBackupMetadataSubset() {
        corruptSubsetOfManagedPaths()
    }
    
    private func verifyBugsnagIsStarted() {
        assert(Bugsnag.isStarted(), "Bugsnag should be started")
    }
    
    private func verifyBugsnagIsNotStarted() {
        assert(!Bugsnag.isStarted(), "Bugsnag should not be started initially")
    }
    
    private func reportStatusOk() {
        Bugsnag.notify(NSException(name: NSExceptionName("InternalWorkingsScenario"),
                reason: "All Clear!",
                userInfo: nil))
    }

    private func modeContains(_ token: String) -> Bool {
        guard let firstArg = args.first else {
            return false
        }
        return firstArg.hasPrefix(backupModePrefix) && firstArg.contains(token)
    }

    private func managedPaths() -> [(name: String, path: String, required: Bool)] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let root = appSupport
            .appendingPathComponent("com.bugsnag.Bugsnag")
            .appendingPathComponent(bundleID)
            .appendingPathComponent("v1")

        let eventsDir = root.appendingPathComponent("events")
        let sessionsDir = root.appendingPathComponent("sessions")
        let breadcrumbsDir = root.appendingPathComponent("breadcrumbs")
        let featureFlagsDir = root.appendingPathComponent("featureFlags")
        let kscDir = root.appendingPathComponent("KSCrashReports")

        var paths: [(name: String, path: String, required: Bool)] = [
            ("rootDirectory", root.path, true),
            ("eventsDirectory", eventsDir.path, true),
            ("sessionsDirectory", sessionsDir.path, true),
            ("breadcrumbsDirectory", breadcrumbsDir.path, true),
            ("featureFlagsDirectory", featureFlagsDir.path, true),
            ("configurationJson", root.appendingPathComponent("config.json").path, true),
            ("stateJson", root.appendingPathComponent("state.json").path, true),
            ("systemStateJson", root.appendingPathComponent("system_state.json").path, true)
        ]

        if FileManager.default.fileExists(atPath: kscDir.path) {
            paths.append(("kscrashReportsDirectory", kscDir.path, true))
        } else {
            paths.append(("kscrashReportsDirectory", kscDir.path, false))
        }

        // in the directory. After successful upload (HTTP 200), directories may
        // be legitimately empty — this is not a backup metadata failure.
        let eventsFilePath = firstNonDirectoryItem(in: eventsDir)?.path ?? ""
        paths.append(("eventsFile", eventsFilePath, !eventsFilePath.isEmpty))

        let sessionsFilePath = firstNonDirectoryItem(in: sessionsDir)?.path ?? ""
        paths.append(("sessionsFile", sessionsFilePath, !sessionsFilePath.isEmpty))

        let breadcrumbsFilePath = firstNonDirectoryItem(in: breadcrumbsDir)?.path ?? ""
        paths.append(("breadcrumbsFile", breadcrumbsFilePath, !breadcrumbsFilePath.isEmpty))

        return paths
    }

    private func firstNonDirectoryItem(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        return children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first(where: { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory == false
        })
    }

    private func backupExclusionValue(path: String) -> Bool? {
        guard !path.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]) else {
            return nil
        }
        return values.isExcludedFromBackup
    }

    private func makeBackupSnapshot(expectedExcluded: Bool) -> (summary: [String: Any], paths: [String: Any]) {
        let fm = FileManager.default
        let allPaths = managedPaths()
        var invalidCount = 0
        var missingRequiredCount = 0
        var details: [String: Any] = [:]

        for item in allPaths {
            let exists = !item.path.isEmpty && fm.fileExists(atPath: item.path)
            if item.required && !exists {
                missingRequiredCount += 1
            }

            var matchesExpectation = true
            var exclusionValue: Int = -1
            if exists {
                if let excluded = backupExclusionValue(path: item.path) {
                    exclusionValue = excluded ? 1 : 0
                    matchesExpectation = excluded == expectedExcluded
                }
            } else if item.required {
                matchesExpectation = false
            }

            if !matchesExpectation {
                invalidCount += 1
            }

            details[item.name] = [
                "path": item.path,
                "required": item.required ? 1 : 0,
                "exists": exists ? 1 : 0,
                "isExcludedFromBackup": exclusionValue,
                "matchesExpectation": matchesExpectation ? 1 : 0
            ]
        }

        let integrity = jsonFilesAreReadable()
        let unrelated = unrelatedPathStatus()
        let summary: [String: Any] = [
            "mode": args.first ?? "",
            "expectedExcludedFromBackup": expectedExcluded ? 1 : 0,
            "checkedPathCount": allPaths.count,
            "invalidPathCount": invalidCount,
            "missingRequiredPathCount": missingRequiredCount,
            "jsonIntegrityOk": integrity ? 1 : 0,
            "unrelatedPathChecked": unrelated.checked ? 1 : 0,
            "unrelatedPathUnchanged": unrelated.unchanged ? 1 : 0
        ]
        return (summary, details)
    }

    private func jsonFilesAreReadable() -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let root = appSupport
            .appendingPathComponent("com.bugsnag.Bugsnag")
            .appendingPathComponent(bundleID)
            .appendingPathComponent("v1")
        let jsonFiles = ["config.json", "state.json", "system_state.json"]
        for name in jsonFiles {
            let path = root.appendingPathComponent(name).path
            guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else {
                return false
            }
            if (try? JSONSerialization.jsonObject(with: data, options: [])) == nil {
                return false
            }
        }
        return true
    }

    private func createUnrelatedFileMarker() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let unrelatedPath = appSupport.appendingPathComponent(unrelatedFilename).path
        let marker = "This file is unrelated to SDK-managed paths."
        _ = try? marker.data(using: .utf8)?.write(to: URL(fileURLWithPath: unrelatedPath))
        setBackupExclusion(path: unrelatedPath, excluded: false)
    }

    private func unrelatedPathStatus() -> (checked: Bool, unchanged: Bool) {
        guard modeContains("unrelated") else {
            return (false, true)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let unrelatedPath = appSupport.appendingPathComponent(unrelatedFilename).path
        let unchanged = backupExclusionValue(path: unrelatedPath) == false
        return (true, unchanged)
    }

    private func setBackupExclusion(path: String, excluded: Bool) {
        guard !path.isEmpty else { return }
        var isDirectory = ObjCBool(false)
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) { return }
        var url = URL(fileURLWithPath: path)   // ← change 'let' to 'var'
        var mutableValues = URLResourceValues()
        mutableValues.isExcludedFromBackup = excluded
        try? url.setResourceValues(mutableValues)
    }

    private func corruptSubsetOfManagedPaths() {
        let expectedExcluded = !config.fileBackupSupport
        // Invert a few known paths so startup normalization can reconcile mixed state.
        for item in managedPaths().prefix(3) {
            setBackupExclusion(path: item.path, excluded: !expectedExcluded)
        }
    }
}
