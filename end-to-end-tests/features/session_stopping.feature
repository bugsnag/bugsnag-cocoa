Feature: Stopping and resuming sessions

Scenario: When a session is stopped the error has no session information
    When I run "StoppedSessionScenario"
    And I wait to receive 2 requests
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And each event in the payload matches one of:
        | exceptions.0.message                                           | has session |
        | The operation couldn’t be completed. (First error error 101.)  | yes         |
        | The operation couldn’t be completed. (Second error error 101.) | no          |

Scenario: When a session is resumed the error uses the previous session information
    When I run "ResumedSessionScenario"
    And I wait to receive 2 requests
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "sessions.0.id" is stored as the value "session_id"
    And the payload field "sessions.0.startedAt" is stored as the value "started_at"
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events.1.session.id" equals the stored value "session_id"
    And the payload field "events.1.session.startedAt" equals the stored value "started_at"
    And each event in the payload matches one of:
        | exceptions.0.message                                           | session.events.handled |
        | The operation couldn’t be completed. (First error error 101.)  | 1                      |
        | The operation couldn’t be completed. (Second error error 101.) | 2                      |

Scenario: When a new session is started the error uses different session information
    When I run "NewSessionScenario"
    And I wait to receive 3 requests
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events.0.session.id" is stored as the value "session_id_one"
    And the payload field "events.1.session.id" does not equal the stored value "session_id_one"
    And each event in the payload matches one of:
        | exceptions.0.message                                           | session.events.handled |
        | The operation couldn’t be completed. (First error error 101.)  | 1                      |
        | The operation couldn’t be completed. (Second error error 101.) | 1                      |
