Feature: CaptureOptions passed to notify call that limit what fields are sent in an event

  Scenario: Disable breadcrumbs with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_breadcrumb"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2.msg2" equals "My message2"
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread information is valid for the event
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event
    And the event has no breadcrumbs

  Scenario: Disable feature flags with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_feature_flags"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2.msg2" equals "My message2"
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread information is valid for the event
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event
    And the event has no feature flags

  Scenario: Disable stacktrace with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_stacktrace"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2.msg2" equals "My message2"
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread with id "0" contains the error reporting flag
    And the event has no stacktrace

  Scenario: Disable threads with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_threads"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2.msg2" equals "My message2"
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event
    And the event has no threads

  Scenario: Disable user with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_user"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2.msg2" equals "My message2"
    And the event "unhandled" is false
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread information is valid for the event
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event
    And the event has no user

  Scenario: Disable all metadata with CaptureOptions except for app and device
    When I run "CaptureOptionsScenario"
    And I invoke "metadata_empty"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom" is null
    And the event "metaData.custom2" is null
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread information is valid for the event
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event

  Scenario: Disable specific metadata with CaptureOptions
    When I run "CaptureOptionsScenario"
    And I invoke "disable_specific_section_metadata2"
    And I invoke "notify_manual"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.app.memoryUsage" is a number
    And the event "metaData.device.timezone" is not null
    And the event "metaData.custom.msg" equals "My message"
    And the event "metaData.custom2" is null
    And the event "unhandled" is false
    And the event "user.email" equals "foobar@example.com"
    And the event "user.id" equals "foobar"
    And the event "user.name" equals "Foo Bar"
    And the event "breadcrumbs.1.name" equals "CaptureOptionsScenario breadcrumb"
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | Testing     | e2e            |
    And the exception "errorClass" equals "NSRangeException"
    And the exception "message" equals "Something is out of range"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.app.dsymUUIDs" is a non-empty array
    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And on macOS, the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.model" matches the regex "[iPad|Macmini|iPhone]1?\d,\d"
    And the error payload field "events.0.device.totalMemory" is an integer
    And the thread information is valid for the event
    And the "method" of stack frame 0 matches "CaptureOptionsScenario"
    And the stacktrace is valid for the event


