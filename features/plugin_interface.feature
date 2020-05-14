Feature: Add custom behavior through a plugin interface

    Some internal libraries may build on top of the Bugsnag Cocoa library and
    require custom behavior prior to the library being fully initialized. This
    interface allows for installing that behavior before calling the regular
    initialization process.

    Background:
        Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

    Scenario: Changing payload notifier description
        When I crash the app using "CustomPluginNotifierDescriptionScenario"
        And I relaunch the app
        And I wait for a request
        Then the payload field "notifier.name" equals "Foo Handler Library"
        And the payload field "notifier.version" equals "2.1.0"
        And the payload field "notifier.url" equals "https://example.com"
        And the payload field "events" is an array with 1 element
        And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
