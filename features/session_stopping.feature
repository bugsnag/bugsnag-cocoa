Feature: Stopping and resuming sessions

Scenario: When a session is stopped the error has no session information
    When I run "StoppedSessionScenario"
    And I wait for 3 requests
    Then the request 0 is valid for the session tracking API
    And the request 1 is valid for the error reporting API
    And the request 2 is valid for the error reporting API
    And the request 1 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | null | The operation couldn’t be completed. (Second error error 101.) |
    And the request 2 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | null | The operation couldn’t be completed. (Second error error 101.) |

Scenario: When a session is resumed the error uses the previous session information
    When I run "ResumedSessionScenario"
    And I wait for 3 requests
    Then the request 0 is valid for the session tracking API
    And the request 1 is valid for the error reporting API
    And the request 2 is valid for the error reporting API
    And the payload field "events.0.session.id" of request 1 equals the payload field "events.0.session.id" of request 2
    And the payload field "events.0.session.startedAt" of request 1 equals the payload field "events.0.session.startedAt" of request 2
    And the request 1 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | 2 | The operation couldn’t be completed. (Second error error 101.) |
    And the request 2 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | 2 | The operation couldn’t be completed. (Second error error 101.) |

Scenario: When a new session is started the error uses different session information
    When I run "NewSessionScenario"
    And I wait for 4 requests
    Then the request 0 is valid for the session tracking API
    And the request 1 is valid for the session tracking API
    And the request 2 is valid for the error reporting API
    And the request 3 is valid for the error reporting API
    And the payload field "events.0.session.id" of request 2 does not equal the payload field "events.0.session.id" of request 3
    And the request 2 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | 1 | The operation couldn’t be completed. (Second error error 101.) |
    And the request 3 matches one of:
        | session.events.handled | exceptions.0.message |
        | 1  | The operation couldn’t be completed. (First error error 101.) |
        | 1 | The operation couldn’t be completed. (Second error error 101.) |