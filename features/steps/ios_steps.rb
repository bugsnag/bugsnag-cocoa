When("I run {string}") do |event_type|
  wait_time = RUNNING_CI ? '20' : '1'
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{event_type}"
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
When("I crash the app using {string}") do |event|
  steps %Q{
    When I set environment variable "EVENT_TYPE" to "#{event}"
    And I set environment variable "EVENT_MODE" to "normal"
    And I launch the app
    And I set environment variable "EVENT_MODE" to "noevent"
  }
end

Then("the payload field {string} of request {int} equals the payload field {string} of request {int}") do |field1, request_index1, field2, request_index2|
  value1 = read_key_path(find_request(request_index1)[:body], field1)
  value2 = read_key_path(find_request(request_index2)[:body], field2)
  assert_equal(value1, value2)
end

Then("the payload field {string} of request {int} does not equal the payload field {string} of request {int}") do |field1, request_index1, field2, request_index2|
  value1 = read_key_path(find_request(request_index1)[:body], field1)
  value2 = read_key_path(find_request(request_index2)[:body], field2)
  assert_not_equal(value1, value2)
end

Then("each event in the payload for request {int} matches one of:") do |request_index, table|
  events = read_key_path(find_request(request_index)[:body], "events")
  table.hashes.each do |values|
    assert_not_nil(events.detect do |event|
      handled_count = read_key_path(event, "session.events.handled")
      unhandled_count = read_key_path(event, "session.events.unhandled")
      error_class = read_key_path(event, "exceptions.0.errorClass")
      handled_count == values["handled"].to_i &&
        unhandled_count == values["unhandled"].to_i &&
        error_class == values["class"]
    end, "No event matches the following values: #{values}")
  end
end
