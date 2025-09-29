Feature: Attaching a series of notable events leading up to errors
  A breadcrumb contains supplementary data which will be sent along with
  events. Breadcrumbs are intended to be pieces of information which can
  lead the developer to the cause of the event being reported.

  Background:
    Given I clear all persistent data

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

  Scenario: State breadcrumbs
    When I configure Bugsnag for "DelayedNotifyErrorScenario"
    # Do this just to sync up client and server
    And I invoke "notify_error"
    And I wait to receive an error
    And I discard the oldest error
    # Now we know that the backgrounding will occur at an appropriate time
    And I switch to the web browser for 2 seconds
    # Give iOS sufficient time to raise the notification for foregrounding the app
    And I make the test fixture wait for 1 second
    # This next error should have the notification breadcrumbs
    And I invoke "notify_error"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"
    # Bugsnag has been started too late to capture some early notifications
    And the event has a "state" breadcrumb named "App Did Enter Background"
    And the event has a "state" breadcrumb named "App Will Enter Foreground"
    And the event has a "state" breadcrumb named "Scene Entered Background"
    And the event has a "state" breadcrumb named "Scene Will Enter Foreground"
    # UISceneDidActivateNotification doesn't seem to be sent on app foregrounding anymore
    # And the event has a "state" breadcrumb named "Scene Activated"

