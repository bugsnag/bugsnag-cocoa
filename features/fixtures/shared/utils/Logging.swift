//
//  logging.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 02.11.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

//public func logDebug(_ format: String) {
//    logDebug(format: format, args: 0 as Int)
//}
public func logDebug(_ format: String, _ args: CVarArg...) {
    withVaList(args) {
        logInternal("debug", format, $0)
    }
}

//public func logInfo(_ format: String) {
//    logInfo(format: format, args: 0 as Int)
//}
public func logInfo(_ format: String, _ args: CVarArg...) {
    withVaList(args) {
        logInternal("info", format, $0)
    }
}

//public func logWarn(_ format: String) {
//    logWarn(format: format, args: 0 as Int)
//}
public func logWarn(_ format: String, _ args: CVarArg...) {
    withVaList(args) {
        logInternal("warn", format, $0)
    }
}

//public func logError(_ format: String) {
//    logError(format: format, args: 0 as Int)
//}
public func logError(_ format: String, _ args: CVarArg...) {
    withVaList(args) {
        logInternal("error", format, $0)
    }
}
