Feature: Delivery of errors

  Background:
    Given I clear all persistent data

  @watchos
  Scenario: Delivery is retried after an HTTP 500 error
    When I set the HTTP status code for the next request to 500
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API

  Scenario: Delivery is not retried after an HTTP 400 error
    When I set the HTTP status code for the next request to 400
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    Then I should receive no errors

  Scenario: Delivery is not retried for oversized handled payloads
    Given I set the HTTP status code to 500
    When I run "OversizedHandledErrorScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    # The error should not have been persited
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "OversizedHandledErrorScenario"
    Then I should receive no errors

  Scenario: Delivery is not retried for old handled payloads
    Given I set the HTTP status code to 500
    When I run "OldHandledErrorScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    # The error should now have been persisted
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "OldHandledErrorScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    # The error should now have been deleted
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "OldHandledErrorScenario"
    Then I should receive no errors

  Scenario: Delivery is not retried for oversized crash payloads
    Given I set the HTTP status code to 500
    When I run "OversizedCrashReportScenario" and relaunch the crashed app
    And I configure Bugsnag for "OversizedCrashReportScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    # The crash report should now have been deleted
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "OversizedCrashReportScenario"
    Then I should receive no errors

  Scenario: Delivery is not retried for old crash payloads
    Given I set the HTTP status code to 500
    When I run "OldCrashReportScenario" and relaunch the crashed app
    And I configure Bugsnag for "OldCrashReportScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    # The crash report should now have been deleted
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "OldCrashReportScenario"
    Then I should receive no errors

  Scenario: Bugsnag.start() should block for 2 seconds after a launch crash
    When I run "SendLaunchCrashesSynchronouslyScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 2.0 and 2.5

  Scenario: Bugsnag.start() should not block if sendLaunchCrashesSynchronously is false
    When I run "SendLaunchCrashesSynchronouslyFalseScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyFalseScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5

  Scenario: Bugsnag.start() should not block for non-launch crashes
    When I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5

  Scenario: Session delivery should be retried for recent payloads
    Given I set the HTTP status code for the next request to 500
    And I run "AutoSessionScenario"
    And I wait to receive a session
    And I wait for the fixture to process the response
    And I kill and relaunch the app
    When I run "AutoSessionScenario"
    Then I wait to receive 3 sessions

  Scenario: Session delivery should not be retried for old payloads
    Given I set the HTTP status code for the next request to 500
    And I set the app to "old" mode
    And I run "OldSessionScenario"
    And I wait to receive a session
    And I wait for the fixture to process the response
    And I discard the oldest session
    And I kill and relaunch the app
    When I set the app to "new" mode
    And I run "OldSessionScenario"
    And I wait to receive a session
    Then the session "user.id" equals "new"
    And I discard the oldest session
    And I should receive no sessions

  Scenario: The oldest sessions should be deleted to comply with maxPersistedSessions
    Given I set the HTTP status code to 500
    And I run "MaxPersistedSessionsScenario"
    And I wait to receive 2 sessions
    And the session "user.id" equals "1"
    And I discard the oldest session
    And the session "user.id" equals "2"
    And I discard the oldest session
    When I set the HTTP status code to 200
    And I kill and relaunch the app
    And I run "MaxPersistedSessionsScenario"
    And I wait to receive 3 sessions
    Then the session "user.id" equals "3"
    And I discard the oldest session
    And the session "user.id" equals "2"
    And I discard the oldest session
    And the session "user.id" equals "4"

  Scenario: Breadcrumbs should be trimmed if payload is oversized
    When I run "OversizedBreadcrumbsScenario"
    And I wait to receive an error
    Then the event "breadcrumbs" is an array with 10 elements
    And the error "Content-Length" header matches the regex "^9\d{5}$"
    And the event "breadcrumbs.0.metaData.a" is null
    And the event "breadcrumbs.0.name" equals "Removed, along with 16 older breadcrumbs, to reduce payload size"
    And the event "breadcrumbs.9.metaData.a" is not null
    And the event "breadcrumbs.9.name" equals "Breadcrumb 25"
    And the event "usage.system.breadcrumbBytesRemoved" equals 1602740
    And the event "usage.system.breadcrumbsRemoved" equals 17
    And the event "usage.system.stringCharsTruncated" is not null
    And the event "usage.system.stringsTruncated" is not null

  @skip_ios_17
  # TODO: Skipped Pending PLAT-12398
  @skip_macos
  Scenario Outline: Attempt Delivery On Crash
    When I set the app to "<scenario_mode>" mode
    And I run "AttemptDeliveryOnCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "context" equals "OnSendError"
    And the exception "errorClass" equals "<error_class>"
    And the exception "message" equals "<message>"
    And the event "metaData.error.type" equals "<error_type>"
    And the event "unhandled" is true
    And the event "usage.config.attemptDeliveryOnCrash" is true
    And the event "usage.config.staticallyLinked" equals the platform-dependent boolean:
      | ios     | true  |
      | macos   | @null |
      | watchos | @null |
    And I discard the oldest error
    And I relaunch the app after a crash
    And I configure Bugsnag for "AttemptDeliveryOnCrashScenario"
    And I wait to receive 2 sessions
    Then I should receive no error
    Examples:
      | scenario_mode   | error_type  | error_class      | message                                                   |
      | NSException     | nsexception | NSRangeException | Something is out of range                                 |
      | SwiftFatalError | mach        | Fatal error      | Unexpectedly found nil while unwrapping an Optional value |
      | BadAccess       | mach        | EXC_BAD_ACCESS   | Attempted to dereference garbage pointer 0x20.            |

  @skip_below_ios_17
  @skip_macos
  Scenario Outline: Attempt Delivery On Crash iOS 17
    When I set the app to "<scenario_mode>" mode
    And I run "AttemptDeliveryOnCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "context" equals "OnSendError"
    And the exception "errorClass" equals "<error_class>"
    And the exception "message" equals "<message>"
    And the event "metaData.error.type" equals "<error_type>"
    And the event "unhandled" is true
    And the event "usage.config.attemptDeliveryOnCrash" is true
    And the event "usage.config.staticallyLinked" equals the platform-dependent boolean:
      | ios     | true  |
      | macos   | @null |
      | watchos | @null |
    And I discard the oldest error
    And I relaunch the app after a crash
    And I configure Bugsnag for "AttemptDeliveryOnCrashScenario"
    And I wait to receive 2 sessions
    Then I should receive no error
    Examples:
      | scenario_mode   | error_type  | error_class      | message                                                   |
      | NSException     | nsexception | NSRangeException | Something is out of range                                 |
      | SwiftFatalError | mach        | Fatal error      | Unexpectedly found nil while unwrapping an Optional value |
      | BadAccess       | mach        | EXC_BAD_ACCESS   | Attempted to dereference garbage pointer 0x20.            |
