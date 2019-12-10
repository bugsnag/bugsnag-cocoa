When("I run {string}") do |event_type|
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{event_type}"
    And I launch the app
  }
end

When("I launch the app") do
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
  }
  start = Time.now
  until test_app_is_running?
    raise "Never launched! Waited #{MAX_WAIT_TIME}s." if Time.now - start > MAX_WAIT_TIME

    sleep 0.2
  end
end
When("I relaunch the app") do
  start = Time.now
  while test_app_is_running?
    raise "Never crashed! Waited #{MAX_WAIT_TIME}s." if Time.now - start > MAX_WAIT_TIME

    sleep 0.2
  end
  step('I launch the app')
end
When('the app is unexpectedly terminated') do
  kill_test_app
end
When('the app is interrupted by Siri') do
  steps %Q{
    When I wait for 10 seconds
    And I run the script "features/scripts/activate_siri.sh"
    And I wait for 2 seconds
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
When("I put the app in the background") do
  steps %Q{
    When I run the script "features/scripts/launch_ios_safari.sh" synchronously
    And I wait for 2 seconds
  }
end

Then("each event in the payload for request {int} matches one of:") do |request_index, table|
  # Checks string equality of event fields against values
  events = read_key_path(find_request(request_index)[:body], "events")
  table.hashes.each do |values|
    assert_not_nil(events.detect do |event|
      values.all? do |k, v|
        if k.start_with? 'has '
          event_value = read_key_path(event, k.split(' ').last)
          if v == 'yes'
            !event_value.nil?
          else
            event_value.nil?
          end
        else
          v == read_key_path(event, k) || (v.to_i > 0 && v.to_i == read_key_path(event, k).to_i)
        end
      end
    end, "No event matches the following values: #{values}")
  end
end
Then("each event in the payload matches one of:") do |table|
  step("each event in the payload for request 0 matches one of:", table)
end

Then("each event with a session in the payload for request {int} matches one of:") do |request_index, table|
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

Then("the event {string} is within {int} seconds of the current timestamp") do |field, threshold_secs|
  value = read_key_path(find_request(0)[:body], "events.0.#{field}")
  assert_not_nil(value, "Expected a timestamp")
  nowSecs = Time.now.to_i
  thenSecs = Time.parse(value).to_i
  delta = nowSecs - thenSecs
  assert_true(delta.abs < threshold_secs, "Expected current timestamp, but received #{value}")
end

Then("the event breadcrumbs contain {string}") do |string|
  crumbs = read_key_path(find_request(0)[:body], "events.0.breadcrumbs")
  assert_not_equal(0, crumbs.length, "There are no breadcrumbs on this event")
  match = crumbs.detect do |crumb|
    read_key_path(crumb, "metaData.message") == string
  end
  assert_not_nil(match, "No crumb matches the provided message")
end

Then("the {string} of stack frame {int} demangles to {string}") do |field, frame_index, expected_value|
  value = read_key_path(find_request(0)[:body], "events.0.exceptions.0.stacktrace.#{frame_index}.#{field}")
  demangled_value = `xcrun swift-demangle -compact '#{value}'`.chomp
  assert_equal(expected_value, demangled_value)
end

Then("the stack trace is an array with {int} stack frames") do |expected_length|
  stack_trace = read_key_path(find_request(0)[:body], "events.0.exceptions.0.stacktrace")
  assert_equal(expected_length,  stack_trace.length)
end
Then("the payload field {string} equals the device version") do |field|
  value = read_key_path(find_request(0)[:body], field)
  assert_equal(MAZE_SDK, value)
end

Then("the stacktrace contains methods:") do |table|
  stack_trace = read_key_path(find_request(0)[:body], "events.0.exceptions.0.stacktrace")
  expected = table.raw.flatten
  actual = stack_trace.map{|s| s["method"]}
  contains = actual.each_cons(expected.length).to_a.include? expected
  assert_true(contains, "Stacktrace methods #{actual} did not contain #{expected}")
end
