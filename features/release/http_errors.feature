Feature: BugsnagNetworkRequestPlugin will send an error that wraps http request/response if the status code matches one of the configured codes.

  Background:
    Given I clear all persistent data

  Scenario: Failed GET requests send error reports when configured
    When I run "HttpErrorSendScenario"
    And I wait to receive 2 reflections
    Then I wait to receive 1 error
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HTTPError"
    And the exception "message" matches "444: http://.*:[89]\d{3}/reflect"

    # Validate request fields
    And the event "request.httpMethod" equals "GET"
    And the event "request.httpVersion" is not null
    And the event "request.url" matches "^https?\:\/\/.+"
    And the event "request.params.password" equals "[REDACTED]"
    And the event "request.params.status" equals "444"
    And the event "request.headers" is not null

    # Validate response fields
    And the event "response.statusCode" equals 444
    And the event "response.headers" is not null

    # Validate the event breadcrumbs
    And the event "breadcrumbs.0.timestamp" is a timestamp
    And the event "breadcrumbs.0.name" equals "NSURLSession request failed"
    And the event "breadcrumbs.0.type" equals "request"
    And the event "breadcrumbs.0.metaData.method" equals "GET"
    And the event "breadcrumbs.0.metaData.url" matches "http://.*:[89]\d{3}/reflect"
    And the event "breadcrumbs.0.metaData.urlParams.status" equals "444"
    And the event "breadcrumbs.0.metaData.urlParams.password" equals "[REDACTED]"
    And the event "breadcrumbs.0.metaData.status" equals 444
    And the event "breadcrumbs.0.metaData.duration" is greater than 0
    And the event "breadcrumbs.0.metaData.requestContentLength" is null
    And the event "breadcrumbs.0.metaData.responseContentLength" is greater than 0

  Scenario: Failed POST requests send error reports when configured, body is truncated
    When I run "HttpErrorSendPostScenario"
    And I wait to receive 2 reflections
    Then I wait to receive 1 error
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HTTPError"
    And the exception "message" matches "400: http://.*:[89]\d{3}/reflect"

    # Validate request fields
    And the event "request.httpMethod" equals "POST"
    And the event "request.httpVersion" is not null
    And the event "request.url" matches "^https?\:\/\/.+"
    And the event "request.bodyLength" equals 74
    #And the event "request.body" matches "^{\"status\"\:\"400\",\"myf"
    And the event "request.headers" is not null

    # Validate response fields
    And the event "response.statusCode" equals 400
    And the event "response.headers" is not null

  Scenario: Adding onResponse callbacks can change instrumented response fields
    When I run "HttpErrorOnResponseCallbackScenario"
    And I wait to receive 2 reflections
    Then I wait to receive 1 error
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HTTPError"
    And the exception "message" matches "444: http://.*:[89]\d{3}/reflect"

    # Validate request fields
    And the event "request.httpMethod" equals "GET"
    And the event "request.httpVersion" is not null
    And the event "request.url" matches "^https?\:\/\/.+"
    And the event "request.params.password" equals "[REDACTED]"

    # Validate response fields
    And the event "response.statusCode" equals 444
    And the event "response.body" equals "This is a response body that should be reported with the error"
    And the event has no breadcrumbs

  Scenario: Adding onError callbacks can change reported event fields
    When I run "HttpErrorOnErrorCallbackScenario"
    And I wait to receive 2 reflections
    Then I wait to receive 1 error
    And the error payload field "events" is an array with 1 elements
    And the event "context" matches "HttpErrorOnErrorCallbackScenario context"
    And the exception "errorClass" equals "HTTPError"
    And the exception "message" matches "500: http://.*:[89]\d{3}/reflect"

    # Validate request fields
    And the event "request.httpMethod" equals "GET"
    And the event "request.httpVersion" is not null
    And the event "request.url" matches "^https?\:\/\/.+"
    And the event "request.params.status" equals "500"
    And the event "request.headers" is not null

    # Validate response fields
    And the event "response.statusCode" equals 500