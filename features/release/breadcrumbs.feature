Feature: Attaching a series of notable events leading up to errors
  A breadcrumb contains supplementary data which will be sent along with
  events. Breadcrumbs are intended to be pieces of information which can
  lead the developer to the cause of the event being reported.

  Background:
    Given I clear all persistent data

  Scenario: Manually leaving a breadcrumb of a discarded type and discarding automatic
    When I run "DiscardedBreadcrumbTypeScenario"
    And I wait to receive an error
    Then the event has a "log" breadcrumb named "Noisy event"
    And the event has a "process" breadcrumb named "Important event"
    And the event does not have a "event" breadcrumb

  Scenario: Leaving breadcrumbs when enabledBreadcrumbTypes is empty
    When I run "EnabledBreadcrumbTypesIsNilScenario"
    And I wait to receive an error
    Then the event has a "log" breadcrumb named "Noisy event"
    And the event has a "process" breadcrumb named "Important event"

  Scenario: An app lauches and subsequently sends a manual event using notify()
    When I run "HandledErrorScenario"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"

  Scenario: An app lauches and subsequently crashes
    When I run "BuiltinTrapScenario" and relaunch the crashed app
    And I configure Bugsnag for "BuiltinTrapScenario"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"

  Scenario: Modifying a breadcrumb name
    When I run "ModifyBreadcrumbScenario"
    And I wait to receive an error
    Then the event has a "manual" breadcrumb named "Cache locked"

  Scenario: Modifying a breadcrumb name in callback
    When I run "ModifyBreadcrumbInNotifyScenario"
    And I wait to receive an error
    Then the event has a "manual" breadcrumb named "Cache locked"

  @skip_below_ios_13
  @skip_macos
  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    And I invoke "notify_error_on_foreground"
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # This next error should have the notification breadcrumbs
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  @watchos
  Scenario: Network breadcrumbs
    When I run "NetworkBreadcrumbsScenario"
    Then I wait to receive an error
    And the event "breadcrumbs.0.timestamp" is a timestamp
    And the event "breadcrumbs.0.name" equals "NSURLSession request failed"
    And the event "breadcrumbs.0.type" equals "request"
    And the event "breadcrumbs.0.metaData.method" equals "GET"
    And the event "breadcrumbs.0.metaData.url" matches "http://.*:[89]\d{3}/reflect/"
    And the event "breadcrumbs.0.metaData.urlParams.status" equals "444"
    And the event "breadcrumbs.0.metaData.urlParams.password" equals "[REDACTED]"
    And the event "breadcrumbs.0.metaData.status" equals 444
    And the event "breadcrumbs.0.metaData.duration" is greater than 0
    And the event "breadcrumbs.0.metaData.requestContentLength" is null
    And the event "breadcrumbs.0.metaData.responseContentLength" is greater than 0
    And the event "breadcrumbs.1.timestamp" is a timestamp
    And the event "breadcrumbs.1.name" equals "NSURLSession request succeeded"
    And the event "breadcrumbs.1.type" equals "request"
    And the event "breadcrumbs.1.metaData.method" equals "GET"
    And the event "breadcrumbs.1.metaData.url" matches "http://.*:9\d{3}/reflect/"
    And the event "breadcrumbs.1.metaData.urlParams.delay_ms" equals "3000"
    And the event "breadcrumbs.1.metaData.status" equals 200
    And the event "breadcrumbs.1.metaData.duration" is greater than 0
    And the event "breadcrumbs.1.metaData.requestContentLength" is null
    And the event "breadcrumbs.1.metaData.responseContentLength" is greater than 0
