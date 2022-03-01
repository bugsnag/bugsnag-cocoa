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
  step 'the app is not running'
  case Maze::Helper.get_current_platform
  when 'ios'
    Maze.driver.launch_app
  end
end

#
# Setting scenario mode
#

When('I set the app to {string} mode') do |mode|
  $scenario_mode = mode
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

# No platform relevance

When('I clear the error queue') do
  Maze::Server.errors.clear
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
    $scenario_mode = nil
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
  `kill -s SIGTERM #{$fixture_pid}` if $fixture_pid
  $fixture_pid = Process.spawn(
    Maze::Runner.environment,
    'features/fixtures/macos/output/macOSTestApp.app/Contents/MacOS/macOSTestApp',
    [:err, :out] => 'macOSTestApp.log'
  )
  # Required to allow the non-blocking app to fully start before exiting
  sleep(2)
end

