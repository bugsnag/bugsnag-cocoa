When("I run {string}") do |event_type|
  steps %Q{
    Given the element "scenario_name" is present
    When I send the keys "#{event_type}" to the element "scenario_name"
    And I close the keyboard
    And I click the element "run_scenario"
  }
end

When("I set the app to {string} mode") do |mode|
  steps %Q{
    Given the element "scenario_metadata" is present
    When I send the keys "#{mode}" to the element "scenario_metadata"
    And I close the keyboard
  }
end

When("I run {string} and relaunch the app") do |event_type|
  steps %Q{
    When I run "#{event_type}"
    And I relaunch the app
  }
end

When("I clear all persistent data") do
  steps %Q{
    Given the element "clear_persistent_data" is present
    And I click the element "clear_persistent_data"
  }
end

When("I close the keyboard") do
  steps %Q{
    Given the element "close_keyboard" is present
    And I click the element "close_keyboard"
  }
end

When("I configure Bugsnag for {string}") do |event_type|
  steps %Q{
    Given the element "scenario_name" is present
    When I send the keys "#{event_type}" to the element "scenario_name"
    And I close the keyboard
    And I click the element "start_bugsnag"
  }
end

When("I send the app to the background") do
  MazeRunner.driver.background_app(-1)
end

When("I relaunch the app") do
  # This step should only be used when the app has crashed, but the notifier needs a little
  # time to write the crash report before being forced to reopen.
  sleep(2)
  MazeRunner.driver.launch_app
end

When("I clear the error queue") do
  Maze::Server.errors.clear
end

When("derp {string}") do |value|
  send_keys_to_element("scenario_name", value)
end

# 0: The current application state cannot be determined/is unknown
# 1: The application is not running
# 2: The application is running in the background and is suspended
# 3: The application is running in the background and is not suspended
# 4: The application is running in the foreground
Then("The app is running in the foreground") do
  wait_for_true do
    status = MazeRunner.driver.execute_script('mobile: queryAppState', {bundleId: "com.bugsnag.iOSTestApp"})
    status == 4
  end
end

Then("The app is running in the background") do
  wait_for_true do
    status = MazeRunner.driver.execute_script('mobile: queryAppState', {bundleId: "com.bugsnag.iOSTestApp"})
    status == 3
  end
end

Then("The app is not running") do
  wait_for_true do
    status = MazeRunner.driver.execute_script('mobile: queryAppState', {bundleId: "com.bugsnag.iOSTestApp"})
    status == 1
  end
end

def request_matches_row(body, row)
  row.each do |key, expected_value|
    obs_val = read_key_path(body, key)
    next if ("null".eql? expected_value) && obs_val.nil? # Both are null/nil
    next if !obs_val.nil? && (expected_value.to_s.eql? obs_val.to_s) # Values match
    # Match not found - return false
    return false
  end
  # All matched - return true
  true
end

Then("the payload field {string} is equal for error {int} and error {int}") do |key, index_a, index_b|
  assert_true(request_fields_are_equal(key, index_a, index_b))
end

Then("the payload field {string} is not equal for error {int} and error {int}") do |key, index_a, index_b|
  assert_false(request_fields_are_equal(key, index_a, index_b))
end

def request_fields_are_equal(key, index_a, index_b)
  requests = Maze::Server.errors.remaining
  assert_true(requests.length > index_a, "Not enough requests received to access index #{index_a}")
  assert_true(requests.length > index_b, "Not enough requests received to access index #{index_b}")
  request_a = requests[index_a][:body]
  request_b = requests[index_b][:body]
  val_a = read_key_path(request_a, key)
  val_b = read_key_path(request_b, key)
  $logger.info "Comparing '#{val_a}' against '#{val_b}'"
  val_a.eql? val_b
end

Then("the event {string} is within {int} seconds of the current timestamp") do |field, threshold_secs|
  value = read_key_path(Maze::Server.errors.current[:body], "events.0.#{field}")
  assert_not_nil(value, "Expected a timestamp")
  now_secs = Time.now.to_i
  then_secs = Time.parse(value).to_i
  delta = now_secs - then_secs
  assert_true(delta.abs < threshold_secs, "Expected current timestamp, but received #{value}")
end

Then("the event breadcrumbs contain {string} with type {string}") do |string, type|
  crumbs = read_key_path(find_request(0)[:body], "events.0.breadcrumbs")
  assert_not_equal(0, crumbs.length, "There are no breadcrumbs on this event")
  match = crumbs.detect do |crumb|
    crumb["name"] == string && crumb["type"] == type
  end
  assert_not_nil(match, "No crumb matches the provided message and type")
end

Then("the event breadcrumbs contain {string}") do |string|
  crumbs = read_key_path(Maze::Server.errors.current[:body], "events.0.breadcrumbs")
  assert_not_equal(0, crumbs.length, "There are no breadcrumbs on this event")
  match = crumbs.detect do |crumb|
    crumb["name"] == string
  end
  assert_not_nil(match, "No crumb matches the provided message")
end

Then("the stack trace is an array with {int} stack frames") do |expected_length|
  stack_trace = read_key_path(Maze::Server.errors.current[:body], "events.0.exceptions.0.stacktrace")
  assert_equal(expected_length, stack_trace.length)
end

Then("the stacktrace contains methods:") do |table|
  stack_trace = read_key_path(Maze::Server.errors.current[:body], "events.0.exceptions.0.stacktrace")
  expected = table.raw.flatten
  actual = stack_trace.map { |s| s["method"] }
  contains = actual.each_cons(expected.length).to_a.include? expected
  assert_true(contains, "Stacktrace methods #{actual} did not contain #{expected}")
end

def check_device_model(field, list)
  internal_names = {
      "iPhone 6" => %w[iPhone7,2],
      "iPhone 6 Plus" => %w[iPhone7,1],
      "iPhone 6S" => %w[iPhone8,1],
      "iPhone 7" => %w[iPhone9,1 iPhone9,2 iPhone9,3 iPhone9,4],
      "iPhone 8" => %w[iPhone10,1 iPhone10,4],
      "iPhone 8 Plus" => %w[iPhone10,2 iPhone10,5],
      "iPhone 11" => %w[iPhone12,1],
      "iPhone 11 Pro" => %w[iPhone12,3],
      "iPhone 11 Pro Max" => %w[iPhone12,5],
      "iPhone X" => %w[iPhone10,3 iPhone10,6],
      "iPhone XR" => %w[iPhone11,8],
      "iPhone XS" => %w[iPhone11,2 iPhone11,4 iPhone11,8]
  }
  expected_model = MazeRunner.config.capabilities['device']
  valid_models = internal_names[expected_model]
  device_model = read_key_path(list.current[:body], field)
  assert_true(valid_models.include?(device_model), "The field #{device_model} did not match any of the list of expected fields")
end

Then("the payload field {string} matches the test device model") do |field|
  check_device_model field, Maze::Server.errors
end

Then("the session payload field {string} matches the test device model") do |field|
  check_device_model field, Maze::Server.sessions
end

Then("the thread information is valid for the event") do
  # veriy that thread/stacktrace information was captured at all
  thread_traces = read_key_path(Maze::Server.errors.current[:body], "events.0.threads")
  stack_traces = read_key_path(Maze::Server.errors.current[:body], "events.0.exceptions.0.stacktrace")
  assert_not_nil(thread_traces, "No thread trace recorded")
  assert_not_nil(stack_traces, "No thread trace recorded")
  assert_true(stack_traces.count() > 0, "Expected stacktrace collected to be > 0.")
  assert_true(thread_traces.count() > 0, "Expected number of threads collected to be > 0.")

  # verify threads are recorded and contain plausible information (id, type, stacktrace)
  thread_traces.each do |thread|
    assert_not_nil(thread["id"], "Thread ID missing for #{thread}")
    assert_equal("cocoa", thread["type"], "Thread type does not equal 'cocoa' for #{thread}")
    stacktrace = thread["stacktrace"]
    assert_not_nil(stacktrace, "Stacktrace is null for #{thread}")
    stack_traces.each do |frame|
      assert_not_nil(frame["method"], "Method is null for frame #{frame}")
    end
  end

  # verify the errorReportingThread is present and set for only oine thread
  err_thread_count = 0
  err_thread_trace = nil
  thread_traces.each.with_index do |thread, index|
    if thread["errorReportingThread"] == true
      err_thread_count += 1
      err_thread_trace = thread["stacktrace"]
    end
  end
  assert_equal(1, err_thread_count, "Expected errorReportingThread to be reported once for threads #{thread_traces}")

  # verify the errorReportingThread stacktrace matches the exception stacktrace
  stack_traces.each_with_index do |frame, index|
    thread_frame = err_thread_trace[index]
    assert_equal(frame, thread_frame, "Thread and stacktrace differ at #{index}. Stack=#{frame}, thread=#{thread_frame}")
  end
end

Then("the exception {string} equals one of:") do |keypath, possible_values|
  value = read_key_path(Maze::Server.errors.current[:body], "events.0.exceptions.0.#{keypath}")
  assert_includes(possible_values.raw.flatten, value)
end

Then("the error is an OOM event") do
  steps %Q{
    Then the exception "message" equals "The app was likely terminated by the operating system while in the foreground"
    And the exception "errorClass" equals "Out Of Memory"
    And the exception "type" equals "cocoa"
    And the payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements
    And the event "severity" equals "error"
    And the event "severityReason.type" equals "outOfMemory"
    And the event "unhandled" is true
  }
end

def wait_for_true
  max_attempts = 300
  attempts = 0
  assertion_passed = false
  until (attempts >= max_attempts) || assertion_passed
    attempts += 1
    assertion_passed = yield
    sleep 0.1
  end
  raise "Assertion not passed in 30s" unless assertion_passed
end

def send_keys_to_element(element_id, text)
  element = find_element(@element_locator, element_id)
  element.clear()
  element.set_value(text)
end
