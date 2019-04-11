When("I run {string}") do |event_type|
  wait_time = '4'
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{event_type}"
    And I launch the app
    And I wait for #{wait_time} seconds
  }
end

When("I launch the app") do
  wait_time = '4'
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for #{wait_time} seconds
  }
end
When("I relaunch the app") do
  wait_time = '4'
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
When("I put the app in the background") do
  steps %Q{
    When I run the script "features/scripts/launch_ios_safari.sh"
    And I wait for 2 seconds
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

When("I corrupt all reports on disk") do
  app_path = `xcrun simctl get_app_container booted com.bugsnag.iOSTestApp`.chomp
  app_path.gsub!(/(.*Containers).*/, '\1')
  files = Dir.glob("#{app_path}/**/KSCrashReports/iOSTestApp/*.json")
  files.each do |path|
    File.open(path, 'w') {|file| file.truncate(0) }
  end
end

Then("each event in the payload matches one of:") do |table|
  # Checks string equality of event fields against values
  events = read_key_path(find_request(0)[:body], "events")
  table.hashes.each do |values|
    assert_not_nil(events.detect do |event|
      values.all? {|k,v| v == read_key_path(event, k) }
    end, "No event matches the following values: #{values}")
  end
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
