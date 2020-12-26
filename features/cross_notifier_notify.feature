Feature: Communicating events between notifiers

  Other Bugsnag libraries include bugsnag-cocoa as a dependency for capturing
  native cocoa crashes, but may have additional events to report, both
  handled and unhandled. Those events should be reported correctly when
  using bugsnag-cocoa as the delivery layer.

  Background:
    Given I clear all persistent data

  Scenario: Report a handled event through internalNotify()
  Report a handled exception, including a custom stacktrace and severity.
  Event counts in the report's session should match the handled-ness.

    When I run "HandledInternalNotifyScenario"
    And I wait to receive a session
    And I wait to receive an error
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "sessions.0.id" is stored as the value "session_id"

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "Handled Error!"
    And the exception "message" equals "Internally reported a handled event"
    And the exception "type" equals "unreal"
    And the event "severity" equals "warning"
    And the event "severityReason.type" equals "handledException"

    And the "method" of stack frame 0 equals "foo()"
    And the "file" of stack frame 0 equals "src/Giraffe.mm"
    And the "lineNumber" of stack frame 0 equals 200
    And the "method" of stack frame 1 equals "bar()"
    And the "file" of stack frame 1 equals "parser.js"
    And the "lineNumber" of stack frame 1 is null
    And the "method" of stack frame 2 equals "yes()"
    And the "file" of stack frame 2 is null
    And the "lineNumber" of stack frame 2 is null
    And the event "unhandled" is false

    And the payload field "events" is an array with 1 elements
    And the payload field "events.0.session.events.handled" equals 1
    And the payload field "events.0.session.events.unhandled" equals 0
    And the payload field "events.0.session.id" equals the stored value "session_id"

  Scenario: Report an unhandled event through internalNotify()
  Report an unhandled exception, including a custom stacktrace and severity.
  Event counts in the report's session should match the handled-ness.

    When I run "UnhandledInternalNotifyScenario"
    And I wait to receive a session
    And I wait to receive an error
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "sessions.0.id" is stored as the value "session_id"

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "Unhandled Error?!"
    And the exception "message" equals "Internally reported an unhandled event"
    And the exception "type" equals "fake"
    And the event "severity" equals "info"
    And the event "severityReason.type" equals "userCallbackSetSeverity"

    And the "method" of stack frame 0 equals "bar()"
    And the "file" of stack frame 0 equals "foo.js"
    And the "lineNumber" of stack frame 0 equals 43
    And the "method" of stack frame 1 equals "baz()"
    And the "file" of stack frame 1 equals "[native code]"
    And the "lineNumber" of stack frame 1 is null
    And the "method" of stack frame 2 equals "is_done()"
    And the "file" of stack frame 2 is null
    And the "lineNumber" of stack frame 2 is null
    And the event "unhandled" is true
    And the event "severityReason.unhandledOverridden" is true

    And the payload field "events" is an array with 1 elements
    And the payload field "events.0.session.events.handled" equals 0
    And the payload field "events.0.session.events.unhandled" equals 1
    And the payload field "events.0.session.id" equals the stored value "session_id"
