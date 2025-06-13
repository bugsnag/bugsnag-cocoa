Feature: Callbacks can access and modify event information

  Background:
    Given I clear all persistent data

  Scenario: Accessing feature flags from the OnSend callback
    When I run "OnSendErrorCallbackFeatureFlagsScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "featureFlags.0.featureFlag" equals "fromStartup"
    And the event "featureFlags.0.variant" equals "a"
    And the event "featureFlags.1.featureFlag" equals "fromCallback"
    And the event "featureFlags.1.variant" equals "a"

  Scenario: Removing an OnSend callback does not affect other OnSend callbacks
    When I run "OnSendCallbackRemovalScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.callbacks.config" is null
    And the event "metaData.callbacks.config2" equals "adding metadata"

  Scenario: An OnErrorCallback can overwrite information for a handled error
    When I run "OnErrorOverwriteScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "app.id" equals "customAppId"
    And the event "context" equals "customContext"
    And the event "device.id" equals "customDeviceId"
    And the event "groupingHash" equals "customGroupingHash"
    And the event "severity" equals "info"
    And the event "user.id" equals "customId"
    And the event "user.email" equals "customEmail"
    And the event "user.name" equals "customName"
    And the event "unhandled" is false

  Scenario: An OnErrorCallback can overwrite unhandled (true) for a handled error
    When I run "OnErrorOverwriteUnhandledTrueScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "app.id" equals "customAppId"
    And the event "context" equals "customContext"
    And the event "device.id" equals "customDeviceId"
    And the event "groupingHash" equals "customGroupingHash"
    And the event "severity" equals "info"
    And the event "user.id" equals "customId"
    And the event "user.email" equals "customEmail"
    And the event "user.name" equals "customName"
    And the event "unhandled" is true
    And the event "severityReason.unhandledOverridden" is true

  Scenario: An OnErrorCallback can overwrite unhandled (false) for a handled error
    When I run "OnErrorOverwriteUnhandledFalseScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "app.id" equals "customAppId"
    And the event "context" equals "customContext"
    And the event "device.id" equals "customDeviceId"
    And the event "groupingHash" equals "customGroupingHash"
    And the event "severity" equals "info"
    And the event "user.id" equals "customId"
    And the event "user.email" equals "customEmail"
    And the event "user.name" equals "customName"
    And the event "unhandled" is false

  Scenario: An OnSend callback can overwrite information for an unhandled error
    When I run "SwiftAssertionScenario" and relaunch the crashed app
    And I configure Bugsnag for "OnSendOverwriteScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "app.id" equals "customAppId"
    And the event "context" equals "customContext"
    And the event "device.id" equals "customDeviceId"
    And the event "groupingHash" equals "customGroupingHash"
    And the event "severity" equals "info"
    And the event "user.id" equals "customId"
    And the event "user.email" equals "customEmail"
    And the event "user.name" equals "customName"

  Scenario: Information set in OnCrashHandler is added to the final report
    When I run "OnCrashHandlerScenario" and relaunch the crashed app
    And I configure Bugsnag for "OnSendOverwriteScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.custom.strVal" equals "customStrValue"
    And the event "metaData.custom.boolVal" is true
    And the event "metaData.custom.intVal" equals 5
    And the event "metaData.complex.objVal.foo" equals "bar"
    And the event "metaData.custom.doubleVal" is not null
    And the event "metaData.complex.arrayVal" is not null

  Scenario: The original error property is populated for a handled NSError
    When I run "OriginalErrorNSErrorScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.custom.hasOriginalError" is true

  Scenario: The original error property is populated for a handled NSException
    When I run "OriginalErrorNSExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.custom.hasOriginalError" is true

  Scenario: OnSend callbacks run in the order in which they were added
    When I run "OnSendCallbackOrderScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.callbacks.notify" equals 0
    And the event "metaData.callbacks.config" equals 1

  Scenario: An uncaught NSException in a notify callback does not affect error delivery
    When I run "NotifyCallbackCrashScenario"
    And I wait to receive an error
    And the error is valid for the error reporting API
    And the event "unhandled" is false
    And the exception "message" equals "The operation couldn’t be completed. (NotifyCallbackCrashScenario error 100.)"
    And the event "metaData.callbacks.beforeCrash" is true
    And the event "metaData.callbacks.afterCrash" is null

  Scenario: An uncaught NSException in an OnSendError callback does not affect error delivery
    When I run "OnSendErrorCallbackCrashScenario"
    And I wait to receive an error
    And the error is valid for the error reporting API
    And the event "unhandled" is false
    And the exception "message" equals "The operation couldn’t be completed. (OnSendErrorCallbackCrashScenario error 100.)"
    And the event "metaData.callbacks.beforeCrash" is true
    And the event "metaData.callbacks.afterCrash" is null
    And the event "metaData.callbacks.secondCallback" is true

  Scenario: Changes made in OnSendError should not be persisted
    Given I set the HTTP status code for the next request to 500
    And I run "OnSendErrorPersistenceScenario"
    And I wait to receive an error
    And I clear the error queue
    # Wait for fixture to receive the response and save the payload
    And I wait for 2 seconds
    And I kill and relaunch the app
    And I configure Bugsnag for "OnSendErrorPersistenceScenario"
    And I wait to receive an error
    Then the event "metaData.unexpected.message" is null
