Feature: Discarding reports based on release stage

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

    Scenario: Crash when release stage is not present in "notify release stages"
        When I crash the app using "CrashWhenReleaseStageNotInNotifyReleaseStages"
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: Crash when release stage is present in "notify release stages"
        When I crash the app using "CrashWhenReleaseStageInNotifyReleaseStages"
        And I relaunch the app
        And I wait for a request
        Then the request is valid for the error reporting API
        And the exception "errorClass" equals "SIGABRT"
        And the event "unhandled" is true
        And the event "app.releaseStage" equals "prod"

    Scenario: Crash when release stage is changed to not present in "notify release stages" before the event
        If the current run has a different release stage than the crashing context,
        the report should only be sent if the release stage was in "notify release stages"
        at the time of the crash. Release stages can change for a single build of an app
        if the app is used as a test harness or if the build can receive code updates,
        such as JavaScript execution contexts.

        When I crash the app using "CrashWhenReleaseStageNotInNotifyReleaseStagesChanges"
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: Crash when release stage is changed to be present in "notify release stages" before the event
        When I crash the app using "CrashWhenReleaseStageInNotifyReleaseStagesChanges"
        And I relaunch the app
        And I wait for a request
        Then the request is valid for the error reporting API
        And the exception "errorClass" equals "SIGABRT"
        And the event "unhandled" is true
        And the event "app.releaseStage" equals "prod"

    Scenario: Notify when release stage is not present in "notify release stages"
        When I run "NotifyWhenReleaseStageNotInNotifyReleaseStages"
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: Notify when release stage is present in "notify release stages"
        When I run "NotifyWhenReleaseStageInNotifyReleaseStages"
        And I wait for a request
        Then the request is valid for the error reporting API
        And the exception "errorClass" equals "iOSTestApp.MagicError"
        And the exception "message" equals "incoming!"
        And the event "unhandled" is false
        And the event "app.releaseStage" equals "prod"
