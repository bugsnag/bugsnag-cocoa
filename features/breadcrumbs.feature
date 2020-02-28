Feature: Attaching a series of notable events leading up to errors
    A breadcrumb contains supplementary data which will be sent along with
    events. Breadcrumbs are intended to be pieces of information which can
    lead the developer to the cause of the event being reported.

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

    Scenario: Leaving a breadcrumb of a discarded type
        When I run "DiscardedBreadcrumbTypeScenario"
        And I wait for a request
        Then the event breadcrumbs do not contain "Noisy event"
        And the event breadcrumbs contain "Important event"

    Scenario: An app lauches and subsequently sends a manual event using notify()
        And I run "HandledErrorScenario"
        And I wait for a request
        Then the event breadcrumbs contain "Bugsnag loaded" with type "state"

    Scenario: An app lauches and subsequently crahes
        And I crash the app using "BuiltinTrapScenario"
        And I relaunch the app
        And I wait for a request
        Then the event breadcrumbs contain "Bugsnag loaded" with type "state"
