Feature: Barebone tests

  Background:
    Given I clear all persistent data

  Scenario: Barebone test: handled errors
    When I run "BareboneTestHandledScenario"
    And I wait to receive a session
    And I wait to receive 2 errors

    Then the session is valid for the session reporting API
    And the session payload field "sessions.0.id" is not null
    And the session "user.id" equals "foobar"
    And the session "user.email" equals "foobar@example.com"
    And the session "user.name" equals "Foo Bar"

    Then the error is valid for the error reporting API
    And the event "app.bundleVersion" equals "12301"
    And the event "app.id" equals the platform-dependent string:
      | ios   | com.bugsnag.iOSTestApp   |
      | macos | com.bugsnag.macOSTestApp |
    And the event "app.inForeground" is true
    And the event "app.isLaunching" is true
    And the event "app.releaseStage" equals "development"
    And the event "app.type" equals the platform-dependent string:
      | ios   | iOS   |
      | macos | macOS |
    And the event "app.version" equals "12.3"
    And the event "breadcrumbs.0.name" equals "Running BareboneTestHandledScenario"
    And the event "breadcrumbs.1.name" equals "This is super <redacted>"
    And the event "device.freeMemory" is less than the event "device.totalMemory"
    And the event "device.id" is not null
    And the event "device.jailbroken" is false
    And the event "device.locale" is not null
    And the event "device.manufacturer" equals "Apple"
    And the event "device.modelNumber" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "device.osName" equals the platform-dependent string:
      | ios   | iOS    |
      | macos | Mac OS |
    And the event "device.osVersion" matches "\d+\.\d+"
    And the event "device.runtimeVersions.clangVersion" is not null
    And the event "device.runtimeVersions.osBuild" is not null
    And the event "device.time" is a timestamp
    And the event "metaData.device.batteryLevel" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.charging" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.orientation" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.simulator" is false
    And the event "metaData.device.timezone" is not null
    And the event "metaData.device.wordSize" is not null
    And the event "metaData.Exception.info" equals "Some error specific information"
    And the event "metaData.Flags.Testing" is true
    And the event "metaData.Other.password" equals "[REDACTED]"
    And the event "severity" equals "warning"
    And the event "severityReason.type" equals "handledException"
    And the event "severityReason.unhandledOverridden" is true
    And the event "threads.0.errorReportingThread" is true
    And the event "threads.0.id" equals "0"
    And the event "threads.0.name" equals "com.apple.main-thread"
    And the event "threads.0.stacktrace.0.method" matches "BareboneTestHandledScenario"
    And the event "unhandled" is true
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "-[__NSSingleObjectArrayI objectAtIndex:]: index 1 beyond bounds [0 .. 0]"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the test device model
    And the error payload field "events.0.device.totalMemory" is an integer
    And the error payload field "events.0.threads" is an array with 1 elements
    And the "method" of stack frame 0 matches "BareboneTestHandledScenario"

    And I discard the oldest error

    Then the error is valid for the error reporting API
    And the event "app.isLaunching" is false
    And the event "breadcrumbs.2.name" equals "NSRangeException"
    And the event "breadcrumbs.2.type" equals "error"
    And the event "breadcrumbs.3.name" equals "About to decode a payload..."
    And the event "metaData.nserror.code" equals 4864
    And the event "metaData.nserror.domain" equals "NSCocoaErrorDomain"
    And the event "metaData.nserror.reason" equals "The data isn’t in the correct format."
    And the event "metaData.nserror.userInfo.NSCodingPath" is not null
    And the event "metaData.nserror.userInfo.NSDebugDescription" equals "The given data was not valid JSON."
    And the event "metaData.nserror.userInfo.NSUnderlyingError" matches "Error Domain=NSCocoaErrorDomain Code=3840"
    And the event "severity" equals "warning"
    And the event "severityReason.type" equals "handledError"
    And the event "severityReason.unhandledOverridden" is null
    And the event "unhandled" is false
    And the exception "errorClass" equals "__SwiftNativeNSError"
    And the exception "message" equals "The data couldn’t be read because it isn’t in the correct format."
    And the exception "type" equals "cocoa"

  Scenario: Barebone test: unhandled error
    When I run "BareboneTestUnhandledErrorScenario" and relaunch the app
    And I set the app to "report" mode
    And I configure Bugsnag for "BareboneTestUnhandledErrorScenario"
    And I wait to receive an error

    Then the error is valid for the error reporting API
    And the event "app.bundleVersion" equals "12301"
    And the event "app.inForeground" is true
    And the event "app.isLaunching" is true
    And the event "app.releaseStage" equals "development"
    And the event "app.type" equals the platform-dependent string:
      | ios   | iOS   |
      | macos | macOS |
    And the event "app.version" equals "12.3"
    And the event "breadcrumbs.0.name" equals "Bugsnag loaded"
    And the event "breadcrumbs.1.name" is null
    And the event "device.freeMemory" is less than the event "device.totalMemory"
    And the event "device.id" is not null
    And the event "device.jailbroken" is false
    And the event "device.locale" is not null
    And the event "device.manufacturer" equals "Apple"
    And the event "device.osName" equals the platform-dependent string:
      | ios   | iOS    |
      | macos | Mac OS |
    And the event "device.osVersion" matches "\d+\.\d+"
    And the event "device.runtimeVersions.clangVersion" is not null
    And the event "device.runtimeVersions.osBuild" is not null
    And the event "device.time" is a timestamp
    And the event "metaData.error.mach.code_name" equals "KERN_INVALID_ADDRESS"
    And the event "metaData.error.mach.code" equals "0x1"
    And the event "metaData.error.mach.exception_name" is not null
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 1
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is true
    And the event "severity" equals "error"
    And the event "severityReason.type" equals "unhandledException"
    And the event "severityReason.unhandledOverridden" is null
    And the event "threads.0.errorReportingThread" is true
    And the event "threads.0.id" equals "0"
    And the event "threads.0.stacktrace.0.method" matches "(assertionFailure|<redacted>)"
    And the event "unhandled" is true
    And the event "user.email" equals "barfoo@example.com"
    And the event "user.id" equals "barfoo"
    And the event "user.name" equals "Bar Foo"
    And the exception "errorClass" equals "Fatal error"
    And the exception "message" equals "Unexpectedly found nil while implicitly unwrapping an Optional value"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the test device model
    And the error payload field "events.0.device.totalMemory" is an integer
    And the "method" of stack frame 0 matches "(assertionFailure|<redacted>)"

  @skip_macos
  Scenario: Barebone test: Out Of Memory
    When I run "OOMScenario"

    And I wait to receive a session
    Then the session is valid for the session reporting API
    And I discard the oldest session

    # Wait for app to be killed for using too much memory
    And I wait for 5 seconds

    And I relaunch the app
    And I configure Bugsnag for "OOMScenario"
    And I wait to receive a session

    Then the session is valid for the session reporting API
    And I discard the oldest session

    And I wait to receive an error
    Then the error is an OOM event
    And the event "app.bundleVersion" is not null
    And the event "app.dsymUUIDs" is not null
    And the event "app.id" equals the platform-dependent string:
      | ios   | com.bugsnag.iOSTestApp   |
      | macos | com.bugsnag.macOSTestApp |
    And the event "app.inForeground" is true
    And the event "app.isLaunching" is true
    And the event "app.type" equals the platform-dependent string:
      | ios   | iOS   |
      | macos | macOS |
    And the event "app.version" is not null
    And the event "breadcrumbs.0.name" equals "Bugsnag loaded"
    And the event "breadcrumbs.1.name" equals "Memory Warning"
    And the event "device.id" is not null
    And the event "device.jailbroken" is false
    And the event "device.locale" is not null
    And the event "device.manufacturer" equals "Apple"
    And the event "device.modelNumber" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "device.osName" equals the platform-dependent string:
      | ios   | iOS    |
      | macos | Mac OS |
    And the event "device.osVersion" matches "\d+\.\d+"
    And the event "device.runtimeVersions.clangVersion" is not null
    And the event "device.runtimeVersions.osBuild" is not null
    And the event "device.time" is null
    And the event "device.totalMemory" is not null
    And the event "metaData.app.name" equals "iOSTestApp"
    And the event "metaData.custom.bar" equals "foo"
    And the event "metaData.device.batteryLevel" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.charging" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.orientation" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.lowMemoryWarning" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the event "metaData.device.simulator" is false
    And the event "metaData.device.timezone" is not null
    And the event "metaData.device.wordSize" is not null
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 1
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is true
    And the event "session.id" is not null
    And the event "session.startedAt" is not null
    And the event "session.events.handled" equals 0
    And the event "session.events.unhandled" equals 1
    And the event "severity" equals "error"
    And the event "severityReason.type" equals "outOfMemory"
    And the event "severityReason.unhandledOverridden" is null
    And the event "unhandled" is true
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is null
    And the error payload field "events.0.app.durationInForeground" is null
    And the error payload field "events.0.device.freeDisk" is null
    And the error payload field "events.0.device.freeMemory" is null
    And the error payload field "events.0.device.model" matches the test device model
    And the error payload field "events.0.device.totalMemory" is an integer
