Feature: Communicating events between notifiers

    Other Bugsnag libraries include bugsnag-cocoa as a dependency for capturing
    native cocoa crashes, but may have additional events to report, both
    handled and unhandled. Those events should be reported correctly when
    using bugsnag-cocoa as the delivery layer.

    Scenario: Report a handled event through internalNotify()
        Report a handled exception, including a custom severity.
        Event counts in the report's session should match the handled-ness.

        When I run "HandledInternalNotifyScenario"
        And I wait for 2 requests
        Then request 0 is valid for the session tracking API
        And request 1 is valid for the error reporting API
        And the exception "errorClass" equals "Handled Error!" for request 1
        And the exception "message" equals "Internally reported a handled event" for request 1
        And the event "severity" equals "warning" for request 1
        And the event "severityReason.type" equals "handledException" for request 1
        And the event "unhandled" is false for request 1

        And the payload field "events" is an array with 1 element for request 1
        And the payload field "events.0.session.events.handled" equals 1 for request 1
        And the payload field "events.0.session.events.unhandled" equals 0 for request 1
        And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0

    Scenario: Report an unhandled event through internalNotify()
        Report an unhandled exception, including a custom severity.
        Event counts in the report's session should match the handled-ness.

        When I run "UnhandledInternalNotifyScenario"
        And I wait for 2 requests
        Then request 0 is valid for the session tracking API
        And request 1 is valid for the error reporting API
        And the exception "errorClass" equals "Unhandled Error?!" for request 1
        And the exception "message" equals "Internally reported an unhandled event" for request 1
        And the event "severity" equals "info" for request 1
        And the event "severityReason.type" equals "userCallbackSetSeverity" for request 1
        And the event "unhandled" is true for request 1

        And the payload field "events" is an array with 1 element for request 1
        And the payload field "events.0.session.events.handled" equals 0 for request 1
        And the payload field "events.0.session.events.unhandled" equals 1 for request 1
        And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0
