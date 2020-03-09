Feature: Enabled error types

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

Scenario: All Crash reporting is disabled
    # Sessions: on, unhandled crashes: off
    When I crash the app using "DisableAllExceptManualExceptionsAndCrashScenario"
    And I relaunch the app
    # Sessions on, unhandled on
    And I crash the app using "NullPointerScenario"
    And I relaunch the app
    And I wait for 3 requests
    And the request 0 is valid for the session tracking API
    And the request 1 is valid for the session tracking API
    And the request 2 is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    # We only see the Null pointer exception
    And the payload field "events.0.exceptions.0.errorClass" equals "EXC_BAD_ACCESS" for request 2

Scenario: All Crash reporting is disabled but manual notification works
    # enabledErrorTypes = None, Generate a manual notification, crash
    When I crash the app using "DisableAllExceptManualExceptionsSendManualAndCrashScenario"
    And I relaunch the app

    # 2 sessions, 1 error
    And I wait for 1 requests
    And the request 0 is valid for the error reporting API
    
Scenario: NSException Crash Reporting is disabled
    When I crash the app using "DisableNSExceptionScenario"
    And I wait for 5 seconds
    And I relaunch the app

    # The third request is the error from the test finishing.  Ordinarily this is an NSGenericException.
    # Example body when NSException reporting is enabled:
    #
    # {
    #   "apiKey": "a35a2a72bd230ac0aa0f52715bbdc6aa",
    #   "payloadVersion": "4.0",
    #   "events": [
    #     {
    #       "metaData": {
    #         "error": {
    #           "nsexception": {
    #             "name": "NSGenericException"
    #           },
    #           "reason": "An uncaught exception! SCREAM.",
    #           "type": "nsexception",
    #           "address": 0
    #         }
    #       },
    #       "exceptions": [
    #         {
    #           "message": "An uncaught exception! SCREAM.",
    #           "errorClass": "NSGenericException",
    #           "stacktrace": ...
    
    And I wait for 1 requests
    And the request 0 is valid for the error reporting API
    And the payload field "events.0.exceptions.0.errorClass" equals "SIGABRT" for request 0
    # TODO: Awaiting a maze-runner empty string assertion
    # And the payload field "events.0.exceptions.0.message" equals "" for request 2
    # And the payload field "events.0.metaData.error.type" equals "signal" for request 2

Scenario: CPP Crash Reporting is disabled

    # A valid CPP crash looks something like:
    #
    # {
    #   "apiKey": "a35a2a72bd230ac0aa0f52715bbdc6aa",
    #   "payloadVersion": "4.0",
    #   "events": [
    #     {
    #       "metaData": {
    #         "error": {
    #           "address": 0,
    #           "type": "cpp_exception",
    #           "cpp_exception": {
    #             "name": "P39disabled_cxx_reporting_kaboom_exception"
    #           }
    #         }
    #       },
    #       "exceptions": [
    #         {
    #           "message": "",
    #           "errorClass": "P39disabled_cxx_reporting_kaboom_exception",
    #           "stacktrace": [
    #           ],
    #           "type": "cocoa"
    #         }
    #       ],

    When I crash the app using "EnabledErrorTypesCxxScenario"
    And I relaunch the app
    And I wait for 5 seconds
    And I wait for 1 requests
    And the request 0 is valid for the error reporting API
    # Not a c++ exception
    And the payload field "events.0.exceptions.0.errorClass" equals "SIGABRT" for request 0
    And the payload field "events.0.metaData.error.type" equals "signal" for request 0

# Typical Mach event:
#
# {
#   "apiKey": "a35a2a72bd230ac0aa0f52715bbdc6aa",
#   "payloadVersion": "4.0",
#   "events": [
#     {
#       "metaData": {
#         "error": {
#           "address": 0,
#           "mach": {
#             "code": 0,
#             "exception_name": "EXC_BAD_ACCESS",
#             "subcode": 8,
#             "exception": 1
#           },
#           "type": "mach"
#         }
#       },
#       "exceptions": [
#         {
#           "message": "Attempted to dereference null pointer.",
#           "errorClass": "EXC_BAD_ACCESS",
#           "stacktrace": ...

Scenario: Mach Crash Reporting is disabled
    When I crash the app using "DisableMachExceptionScenario"
    And I relaunch the app
    And I wait for 1 requests
    And the request 0 is valid for the error reporting API

    # Not a Mach exception
    # The Mach exception gets trampolined to a SEGV signal?
    And the payload field "events.0.exceptions.0.errorClass" equals "SIGSEGV" for request 0
    And the payload field "events.0.metaData.error.type" equals "signal" for request 0

Scenario: Signals Crash Reporting is disabled
    When I crash the app using "DisableSignalsExceptionScenario"
    And I relaunch the app
    And I wait for 5 seconds
    And I wait for 0 request
