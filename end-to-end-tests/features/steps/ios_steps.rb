When("I run {string}") do |event_type|
  steps %Q{
    Given the element "ScenarioNameField" is present
    When I send the keys "#{event_type}" to the element "ScenarioNameField"
    And I close the keyboard
    And I click the element "StartScenarioButton"
  }
end

When("I set the app to {string} mode") do |mode|
  steps %Q{
    Given the element "ScenarioMetaDataField" is present
    When I send the keys "#{mode}" to the element "ScenarioMetaDataField"
    And I close the keyboard
  }
end

When("I run {string} and relaunch the app") do |event_type|
  steps %Q{
    When I run "#{event_type}"
    And I wait for 2 seconds
    And I relaunch the app
  }
end

When("I close the keyboard") do
  steps %Q{
    Given the element "CloseKeyboardItem" is present
    And I click the element "CloseKeyboardItem"
  }
end

When("I configure Bugsnag for {string}") do |event_type|
  steps %Q{
    Given the element "ScenarioNameField" is present
    When I send the keys "#{event_type}" to the element "ScenarioNameField"
    And I close the keyboard
    And I click the element "StartBugsnagButton"
  }
end

When("I relaunch the app") do
  $driver.launch_app
end

Then("each event in the payload matches one of:") do |table|
  # Checks string equality of event fields against values
  events = read_key_path(Server.current_request[:body], "events")
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
          v == read_key_path(event, k) || (v.to_i == read_key_path(event, k).to_i)
        end
      end
    end, "No event matches the following values: #{values}")
  end
end

Then("the event {string} is within {int} seconds of the current timestamp") do |field, threshold_secs|
  value = read_key_path(Server.current_request[:body], "events.0.#{field}")
  assert_not_nil(value, "Expected a timestamp")
  nowSecs = Time.now.to_i
  thenSecs = Time.parse(value).to_i
  delta = nowSecs - thenSecs
  assert_true(delta.abs < threshold_secs, "Expected current timestamp, but received #{value}")
end

Then("the event breadcrumbs contain {string}") do |string|
  crumbs = read_key_path(Server.current_request[:body], "events.0.breadcrumbs")
  assert_not_equal(0, crumbs.length, "There are no breadcrumbs on this event")
  match = crumbs.detect do |crumb|
    read_key_path(crumb, "metaData.message") == string
  end
  assert_not_nil(match, "No crumb matches the provided message")
end

Then("the stack trace is an array with {int} stack frames") do |expected_length|
  stack_trace = read_key_path(Server.current_request[:body], "events.0.exceptions.0.stacktrace")
  assert_equal(expected_length,  stack_trace.length)
end

Then("the stacktrace contains methods:") do |table|
  stack_trace = read_key_path(Server.current_request[:body], "events.0.exceptions.0.stacktrace")
  expected = table.raw.flatten
  actual = stack_trace.map{|s| s["method"]}
  contains = actual.each_cons(expected.length).to_a.include? expected
  assert_true(contains, "Stacktrace methods #{actual} did not contain #{expected}")
end
