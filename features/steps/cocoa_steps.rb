def short_scenario_name(scenario)
  unless scenario.end_with? 'Scenario'
    raise 'All scenario names must end with "Scenario".  ' \
          'There are removed by the test harness and re-added uniformly by the test fixture.'
  end
  scenario.delete_suffix 'Scenario'
end

When('I run {string}') do |event_type|
  steps %(
    When I set the app to "#{short_scenario_name event_type}" scenario
    And I click the element "run_scenario"
  )
end

When("I run {string} and relaunch the crashed app") do |event_type|
  begin
    step("I run \"#{event_type}\"")
  rescue StandardError
    # Ignore on macOS - AppiumForMac raises an error when clicking a button causes the app to crash
    raise unless Maze::Helper.get_current_platform.eql?('macos')

    $logger.warn 'Ignoring error - this is normal for AppiumForMac if a button click causes the app to crash.'
  end
  step('I relaunch the app after a crash')
end

When("I run the configured scenario and relaunch the crashed app") do
  begin
    steps %(
      Given I click the element "run_scenario"
    )
  rescue StandardError
    raise unless Maze::Helper.get_current_platform.eql?('macos')
    $logger.info 'Ignored error raised by AppiumForMac when clicking run_scenario'
  end
  steps %(
    When the app is not running
    Then I relaunch the app
  )
end

When('I clear all persistent data') do
  steps %(
    When I click the element "clear_persistent_data"
  )
end

def click_if_present(element)
  return false unless Maze.driver.wait_for_element(element, 1)

  Maze.driver.click_element(element)
  true
rescue Selenium::WebDriver::Error::NoSuchElementError
  # Ignore - we have seen clicks fail like this despite having just checked for the element's presence
  false
end

When('I configure Bugsnag for {string}') do |event_type|
  steps %(
    When I set the app to "#{short_scenario_name event_type}" scenario
    And I click the element "start_bugsnag"
  )
end

When('I clear the error queue') do
  Maze::Server.errors.clear
end


def request_matches_row(body, row)
  row.each do |key, expected_value|
    obs_val = Maze::Helper.read_key_path(body, key)
    next if ('null'.eql? expected_value) && obs_val.nil? # Both are null/nil
    next if !obs_val.nil? && (expected_value.to_s.eql? obs_val.to_s) # Values match
    # Match not found - return false
    return false
  end
  # All matched - return true
  true
end

Then('the error payload field {string} is equal for error {int} and error {int}') do |key, index_a, index_b|
  Maze.check.true(request_fields_are_equal(key, index_a, index_b))
end

Then('the error payload field {string} is not equal for error {int} and error {int}') do |key, index_a, index_b|
  Maze.check.false(request_fields_are_equal(key, index_a, index_b))
end

def request_fields_are_equal(key, index_a, index_b)
  requests = Maze::Server.errors.remaining
  Maze.check.true(requests.length > index_a, "Not enough requests received to access index #{index_a}")
  Maze.check.true(requests.length > index_b, "Not enough requests received to access index #{index_b}")
  request_a = requests[index_a][:body]
  request_b = requests[index_b][:body]
  val_a = Maze::Helper.read_key_path(request_a, key)
  val_b = Maze::Helper.read_key_path(request_b, key)
  $logger.info "Comparing '#{val_a}' against '#{val_b}'"
  val_a.eql? val_b
end

def check_device_model(field, list)
  internal_names = {
    'iPhone 6' => %w[iPhone7,2],
    'iPhone 6 Plus' => %w[iPhone7,1],
    'iPhone 6S' => %w[iPhone8,1],
    'iPhone 7' => %w[iPhone9,1 iPhone9,2 iPhone9,3 iPhone9,4],
    'iPhone 8' => %w[iPhone10,1 iPhone10,4],
    'iPhone 8 Plus' => %w[iPhone10,2 iPhone10,5],
    'iPhone 11' => %w[iPhone12,1],
    'iPhone 11 Pro' => %w[iPhone12,3],
    'iPhone 11 Pro Max' => %w[iPhone12,5],
    'iPhone X' => %w[iPhone10,3 iPhone10,6],
    'iPhone XR' => %w[iPhone11,8],
    'iPhone XS' => %w[iPhone11,2 iPhone11,4 iPhone11,8]
  }
  expected_model = Maze.config.capabilities['device']
  valid_models = internal_names[expected_model]
  device_model = Maze::Helper.read_key_path(list.current[:body], field)
  Maze.check.true(valid_models != nil ? valid_models.include?(device_model) : true,
                  "The field #{device_model} did not match any of the list of expected fields")
end

Then('the error payload field {string} matches the test device model') do |field|
  check_device_model field, Maze::Server.errors
end

Then('the session payload field {string} matches the test device model') do |field|
  check_device_model field, Maze::Server.sessions
end

Then('the breadcrumb timestamps are valid for the event') do
  device = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.device')
  unless device['time'].nil?
    breadcrumbs = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.breadcrumbs')
    breadcrumbs.each do |breadcrumb|
      assert(breadcrumb['timestamp'] <= device['time'],
        "Expected breadcrumb timestamp (#{breadcrumb['timestamp']}) <= event timestamp (#{device['time']})")
    end
  end
end

Then('the stacktrace is valid for the event') do
  stacktrace = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  # values that are required for symbolication to work
  keys = %w[frameAddress machoFile machoLoadAddress machoUUID machoVMAddress]
  stacktrace.each_with_index do |frame, i|
    keys.each do |key|
      Maze.check.not_nil(frame[key], "Stack frame #{i} is missing #{key}")
    end
  end
end

Then('the thread information is valid for the event') do
  # verify that thread/stacktrace information was captured at all
  thread_traces = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.threads')
  stack_traces = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], 'events.0.exceptions.0.stacktrace')
  Maze.check.not_nil(thread_traces, 'No thread trace recorded')
  Maze.check.not_nil(stack_traces, 'No thread trace recorded')
  Maze.check.true(stack_traces.count() > 0, 'Expected stacktrace collected to be > 0')
  Maze.check.true(thread_traces.count() > 0, 'Expected number of threads collected to be > 0')

  # verify threads are recorded and contain plausible information (id, type, stacktrace)
  thread_traces.each do |thread|
    Maze.check.not_nil(thread['id'], "Thread ID missing for #{thread}")
    Maze.check.equal('cocoa', thread['type'], "Thread type does not equal 'cocoa' for #{thread}")
    stacktrace = thread['stacktrace']
    Maze.check.not_nil(stacktrace, "Stacktrace is null for #{thread}")
    stack_traces.each do |frame|
      Maze.check.not_nil(frame['method'], "Method is null for frame #{frame}")
    end
  end

  # verify the errorReportingThread is present and set for only oine thread
  err_thread_count = 0
  err_thread_trace = nil
  thread_traces.each.with_index do |thread, index|
    if thread['errorReportingThread'] == true
      err_thread_count += 1
      err_thread_trace = thread['stacktrace']
    end
  end
  Maze.check.equal(1,
                   err_thread_count,
                   "Expected errorReportingThread to be reported once for threads #{thread_traces}")

  # verify the errorReportingThread stacktrace matches the exception stacktrace
  stack_traces.each_with_index do |frame, index|
    thread_frame = err_thread_trace[index]
    Maze.check.equal(frame,
                     thread_frame,
                     "Thread and stacktrace differ at #{index}. Stack=#{frame}, thread=#{thread_frame}")
  end
end

Then('the error is valid for the error reporting API') do
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    steps %(
      Then the error is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
      Then the breadcrumb timestamps are valid for the event
    )
  when 'macos'
    steps %(
      Then the error is valid for the error reporting API version "4.0" for the "OSX Bugsnag Notifier" notifier
      Then the breadcrumb timestamps are valid for the event
    )
  else
    raise "Unknown platform: #{platform}"
  end
end

Then('the error is valid for the error reporting API ignoring breadcrumb timestamps') do
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    steps %(
      Then the error is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    )
  when 'macos'
    steps %(
      Then the error is valid for the error reporting API version "4.0" for the "OSX Bugsnag Notifier" notifier
    )
  else
    raise "Unknown platform: #{platform}"
  end
end

Then('the session is valid for the session reporting API') do
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    steps %(
      Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    )
  when 'macos'
    steps %(
      Then the session is valid for the session reporting API version "1.0" for the "OSX Bugsnag Notifier" notifier
    )
  else
    raise "Unknown platform: #{platform}"
  end
end

Then('the exception {string} equals one of:') do |keypath, possible_values|
  value = Maze::Helper.read_key_path(Maze::Server.errors.current[:body], "events.0.exceptions.0.#{keypath}")
  Maze.check.includes(possible_values.raw.flatten, value)
end

Then('the error is an OOM event') do
  steps %(
    Then the exception "message" equals "The app was likely terminated by the operating system while in the foreground"
    And the exception "errorClass" equals "Out Of Memory"
    And the exception "type" equals "cocoa"
    And the error payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements
    And the event "severity" equals "error"
    And the event "severityReason.type" equals "outOfMemory"
    And the event "unhandled" is true
  )
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
  raise 'Assertion not passed in 30s' unless assertion_passed
end

def send_keys_to_element(element_id, text)
  element = find_element(@element_locator, element_id)
  element.clear()
  element.set_value(text)
end
