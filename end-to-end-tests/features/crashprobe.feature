Feature: Reporting crash events

Scenario: Executing privileged instruction
    When I run "PrivilegedInstructionScenario" and relaunch the app
    And I configure Bugsnag for "PrivilegedInstructionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[PrivilegedInstructionScenario run]"

Scenario: Calling __builtin_trap()
    When I run "BuiltinTrapScenario" and relaunch the app
    And I configure Bugsnag for "BuiltinTrapScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[BuiltinTrapScenario run]"

Scenario: Calling abort()
    When I run "AbortScenario" and relaunch the app
    And I configure Bugsnag for "AbortScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "abort"
    And the "method" of stack frame 2 equals "-[AbortScenario run]"

Scenario: Throwing a C++ exception
    When I run "CxxExceptionScenario" and relaunch the app
    And I configure Bugsnag for "CxxExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "P16kaboom_exception"
    And the exception "type" equals "cocoa"
    And the payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements

Scenario: Calling non-existent method
    When I run "NonExistentMethodScenario" and relaunch the app
    And I configure Bugsnag for "NonExistentMethodScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "message" starts with "-[NonExistentMethodScenario santaclaus:]: unrecognized selector sent to instance"
    And the exception "errorClass" equals "NSInvalidArgumentException"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[NSObject(NSObject) doesNotRecognizeSelector:]"
    And the "method" of stack frame 3 equals "___forwarding___"
    And the "method" of stack frame 4 equals "_CF_forwarding_prep_0"
    And the "method" of stack frame 5 equals "-[NonExistentMethodScenario run]"

Scenario: Heap corruption by writing garbage into data areas used by malloc to track allocations
    When I run "CorruptMallocScenario" and relaunch the app
    And I configure Bugsnag for "CorruptMallocScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And The exception reflects malloc corruption occurred

Scenario: Trigger a crash after overwriting the link register
    When I run "OverwriteLinkRegisterScenario" and relaunch the app
    And I configure Bugsnag for "OverwriteLinkRegisterScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference null pointer."
    And the "method" of stack frame 0 equals "-[OverwriteLinkRegisterScenario run]"

Scenario: Attempt to write into a read-only page
    When I run "ReadOnlyPageScenario" and relaunch the app
    And I configure Bugsnag for "ReadOnlyPageScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadOnlyPageScenario run]"

Scenario: Stack overflow
    When I run "StackOverflowScenario" and relaunch the app
    And I configure Bugsnag for "StackOverflowScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "Stack overflow in -[StackOverflowScenario run]"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 1 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 2 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 3 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 4 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 5 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 6 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 7 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 8 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 9 equals "-[StackOverflowScenario run]"

Scenario: Crash inside objc_msgSend()
    When I run "ObjCMsgSendScenario" and relaunch the app
    And I configure Bugsnag for "ObjCMsgSendScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference garbage pointer 0x42."
    And the "method" of stack frame 0 equals "objc_msgSend"

Scenario: Attempt to execute an instruction undefined on the current architecture
    When I run "UndefinedInstructionScenario" and relaunch the app
    And I configure Bugsnag for "UndefinedInstructionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[UndefinedInstructionScenario run]"

Scenario: Send a message to an object whose memory has already been freed
    When I run "ReleasedObjectScenario" and relaunch the app
    And I configure Bugsnag for "ReleasedObjectScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
    And the "method" of stack frame 1 equals "-[ReleasedObjectScenario run]"

# N.B. this scenario is "imprecise" on CrashProbe due to line number info,
# which is not tested here as this would require symbolication
Scenario: Crash within Swift code
    When I run "SwiftCrash" and relaunch the app
    And I configure Bugsnag for "SwiftCrash"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "Unexpectedly found nil while unwrapping an Optional value"
    And the exception "errorClass" equals "Fatal error"

Scenario: Assertion failure in Swift code
    When I run "SwiftAssertion" and relaunch the app
    And I configure Bugsnag for "SwiftAssertion"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "errorClass" equals "Fatal error"
    And the exception "message" equals "several unfortunate things just happened"

Scenario: Dereference a null pointer
    When I run "NullPointerScenario" and relaunch the app
    And I configure Bugsnag for "NullPointerScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "Attempted to dereference null pointer."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[NullPointerScenario run]"

Scenario: Trigger a crash with libsystem_pthread's _pthread_list_lock held
    When I run "AsyncSafeThreadScenario" and relaunch the app
    And I configure Bugsnag for "AsyncSafeThreadScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "message" equals "Attempted to dereference garbage pointer 0x1."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the stacktrace contains methods:
    |pthread_getname_np|
    |-[AsyncSafeThreadScenario run]|

Scenario: Read a garbage pointer
    When I run "ReadGarbagePointerScenario" and relaunch the app
    And I configure Bugsnag for "ReadGarbagePointerScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadGarbagePointerScenario run]"

Scenario: Throw a NSException
    When I run "ObjCExceptionScenario" and relaunch the app
    And I configure Bugsnag for "ObjCExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "An uncaught exception! SCREAM."
    And the exception "errorClass" equals "NSGenericException"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[ObjCExceptionScenario run]"
    And the event "device.time" is within 60 seconds of the current timestamp

Scenario: Access a non-object as an object
    When I run "AccessNonObjectScenario" and relaunch the app
    And I configure Bugsnag for "AccessNonObjectScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "Attempted to dereference garbage pointer 0x10."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
