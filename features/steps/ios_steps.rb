When("I run {string} with the defaults on {string}") do |eventType, simulator|
  wait_time = RUNNING_CI ? '20' : '1'
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{eventType}"
    And I set environment variable "iOS_Simulator" to "#{simulator}"
    And I launch the app
    And I wait for #{wait_time} seconds
  }
end

When("I launch the app") do
  wait_time = RUNNING_CI ? '10' : '5'
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for #{wait_time} seconds
  }
end
When("I relaunch the app") do
  wait_time = RUNNING_CI ? '20' : '9'
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for #{wait_time} seconds
  }
end
When("I configure the app to run on {string}") do |device|
  steps %Q{
    And I set environment variable "iOS_Simulator" to "#{device}"
  }
end
When("I crash the app using {string}") do |event|
  steps %Q{
    When I set environment variable "EVENT_TYPE" to "#{event}"
    And I launch the app
    And I set environment variable "EVENT_MODE" to "noevent"
  }
end

# TODO: move upstream into maze-runner
Then("request {int} is valid for the session tracking API") do |index|
  steps %Q{
    Then the "Bugsnag-API-Key" header is not null for request #{index}
    And the "Content-Type" header equals "application/json" for request #{index}
    And the "Bugsnag-Payload-Version" header equals "1.0" for request #{index}
    And the "Bugsnag-Sent-At" header is a timestamp for request #{index}

    And the payload field "app" is not null for request #{index}
    And the payload field "device" is not null for request #{index}
    And the payload field "notifier.name" is not null for request #{index}
    And the payload field "notifier.url" is not null for request #{index}
    And the payload field "notifier.version" is not null for request #{index}
    And the payload has a valid sessions array for request #{index}
  }
end

Then("request {int} is valid for the error reporting API") do |index|
  steps %Q{
    Then the "Bugsnag-API-Key" header is not null for request #{index}
    And the "Content-Type" header equals "application/json" for request #{index}
    And the "Bugsnag-Sent-At" header is a timestamp for request #{index}

    And the payload field "notifier.name" is not null for request #{index}
    And the payload field "notifier.url" is not null for request #{index}
    And the payload field "notifier.version" is not null for request #{index}
    And the payload field "events" is a non-empty array for request #{index}

    And each element in payload field "events" has "severity" for request #{index}
    And each element in payload field "events" has "severityReason.type" for request #{index}
    And each element in payload field "events" has "unhandled" for request #{index}
    And each element in payload field "events" has "exceptions" for request #{index}
  }
end

Then("the payload field {string} of request {int} equals the payload field {string} of request {int}") do |field1, request_index1, field2, request_index2|
  value1 = read_key_path(find_request(request_index1)[:body], field1)
  value2 = read_key_path(find_request(request_index2)[:body], field2)
  assert_equal(value1, value2)
end
