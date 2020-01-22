Feature: Attaching a series of notable events leading up to errors
    A breadcrumb contains supplementary data which will be sent along with
    events. Breadcrumbs are intended to be pieces of information which can
    lead the developer to the cause of the event being reported.

    Scenario: An app lauches and subsequently sends a manual event using notify()
        When I run "HandledErrorScenario"
        And I wait for a request
        Then the event breadcrumbs contain "Bugsnag loaded" with type "state"

    Scenario: An app lauches and subsequently crahes
        When I crash the app using "BuiltinTrapScenario"
        And I relaunch the app
        And I wait for a request
        Then the event breadcrumbs contain "Bugsnag loaded" with type "state"
