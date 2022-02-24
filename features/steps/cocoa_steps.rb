When('I run {string}') do |scenario_name|
  execute_command :run_scenario, scenario_name
end

When("I run {string} and relaunch the crashed app") do |event_type|
  steps %(
    Given I run \"#{event_type}\"
    And I relaunch the app after a crash
  )
end

When("I run the configured scenario and relaunch the crashed app") do
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    run_and_relaunch
  when 'macos'
    $scenario_mode = $last_scenario[:scenario_mode]
    execute_command($last_scenario[:action], $last_scenario[:scenario_name])
  else
    raise "Unknown platform: #{platform}"
  end
end

def run_and_relaunch
  steps %(
    Given I click the element "run_scenario"
    And the app is not running
    Then I relaunch the app
  )
end

When('I clear all persistent data') do
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    steps %(
      When I click the element "clear_persistent_data"
    )
  when 'macos'
    $reset_data = true
  else
    raise "Unknown platform: #{platform}"
  end
end

When('I configure Bugsnag for {string}') do |scenario_name|
  execute_command :start_bugsnag, scenario_name
end

def execute_command(action, scenario_name)
  platform = Maze::Helper.get_current_platform
  command = { action: action, scenario_name: scenario_name, scenario_mode: $scenario_mode }
  case platform
  when 'ios'
    Maze::Server.commands.add command
    trigger_app_command
    $scenario_mode = nil
    $reset_data = false
    # Ensure fixture has read the command
    count = 100
    sleep 0.1 until Maze::Server.commands.remaining.empty? || (count -= 1) < 1
    raise 'Test fixture did not GET /command' unless Maze::Server.commands.remaining.empty?
  when 'macos'
    Maze::Runner.environment['BUGSNAG_SCENARIO_ACTION'] = action.to_s
    Maze::Runner.environment['BUGSNAG_SCENARIO_NAME'] = scenario_name.to_s
    Maze::Runner.environment['BUGSNAG_SCENARIO_METADATA'] = $scenario_mode.to_s
    Maze::Runner.environment['BUGSNAG_CLEAR_DATA'] = $reset_data ? 'true' : 'false'
    $last_scenario = command
    run_macos_app
    $reset_data = false
  else
    raise "Unknown platform: #{platform}"
  end
end

def trigger_app_command
  platform = Maze::Helper.get_current_platform
  case platform
  when 'ios'
    Maze.driver.click_element :execute_command
  when 'macos'
    run_macos_app
  else
    raise "Unknown platform: #{platform}"
  end
end

When('I relaunch the app') do
  case Maze::Helper.get_current_platform
  when 'macos'
    # Pass
  else
    Maze.driver.launch_app
  end
end

When("I relaunch the app after a crash") do
  # Wait for the app to stop running before relaunching
  case Maze::Helper.get_current_platform
  when 'macos'
    # Allow any operations to complete before the next step
    sleep(2)
  else
    step 'the app is not running'
    Maze.driver.launch_app
  end
end

#
# https://appium.io/docs/en/commands/device/app/app-state/
#
# 0: The current application state cannot be determined/is unknown
# 1: The application is not running
# 2: The application is running in the background and is suspended
# 3: The application is running in the background and is not suspended
# 4: The application is running in the foreground

Then('the app is running in the foreground') do
  wait_for_true do
    Maze.driver.app_state('com.bugsnag.iOSTestApp') == :running_in_foreground
  end
end

Then('the app is running in the background') do
  wait_for_true do
    Maze.driver.app_state('com.bugsnag.iOSTestApp') == :running_in_background
  end
end

Then('the app is not running') do
  wait_for_true do
    case Maze::Helper.get_current_platform
    when 'ios'
      Maze.driver.app_state('com.bugsnag.iOSTestApp') == :not_running
    when 'macos'
      `lsappinfo info -only pid -app com.bugsnag.macOSTestApp`.empty?
    else
      raise "Don't know how to query app state on this platform"
    end
  end
end

#
# Setting scenario mode
#

When('I set the app to {string} mode') do |mode|
  $scenario_mode = mode
end

# No platform relevance

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

def run_macos_app
  Maze::Runner.kill_running_scripts if $reset_data
  Maze::Runner.run_command("features/fixtures/macos/output/#{Maze.config.app}.app/Contents/MacOS/#{Maze.config.app}", blocking: false)
  # Required to allow the non-blocking app to fully start before exiting
  sleep(2)
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
  check_device_model field, Maze::Server.errors if Maze::Helper.get_current_platform.eql?('ios')
end

Then('the session payload field {string} matches the test device model') do |field|
  check_device_model field, Maze::Server.sessions if Maze::Helper.get_current_platform.eql?('ios')
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
