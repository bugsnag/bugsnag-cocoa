Feature: Stopping and resuming sessions

Scenario: When a session is stopped the error has no session information
    When I run "StoppedSessionScenario"
    Then I should receive 2 requests
    And the request 0 is valid for the session tracking API
    And the request 1 is valid for the error reporting API
    And each event in the payload for request 1 matches one of:
        | exceptions.0.message                                           | has session |
        | The operation couldn’t be completed. (First error error 101.)  | yes         |
        | The operation couldn’t be completed. (Second error error 101.) | no          |

Scenario: When a session is resumed the error uses the previous session information
    When I run "ResumedSessionScenario"
    Then I should receive 2 requests
    And the request 0 is valid for the session tracking API
    And the request 1 is valid for the error reporting API
    And the payload field "events.1.session.id" of request 1 equals the payload field "events.0.session.id" of request 1
    And the payload field "events.1.session.startedAt" of request 1 equals the payload field "events.0.session.startedAt" of request 1
    And each event in the payload for request 1 matches one of:
        | exceptions.0.message                                           | session.events.handled |
        | The operation couldn’t be completed. (First error error 101.)  | 1                      |
        | The operation couldn’t be completed. (Second error error 101.) | 2                      |

Scenario: When a new session is started the error uses different session information
    When I run "NewSessionScenario"
    Then I should receive 3 requests
    And the request 0 is valid for the session tracking API
    And the request 1 is valid for the session tracking API
    And the request 2 is valid for the error reporting API
    And the payload field "events.0.session.id" of request 2 does not equal the payload field "events.1.session.id" of request 2
    And each event in the payload for request 2 matches one of:
        | exceptions.0.message                                           | session.events.handled |
        | The operation couldn’t be completed. (First error error 101.)  | 1                      |
        | The operation couldn’t be completed. (Second error error 101.) | 1                      |
