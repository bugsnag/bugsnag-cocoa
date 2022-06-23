When('I run {string}') do |scenario_name|
  execute_command :run_scenario, scenario_name
end

When("I run {string} and relaunch the crashed app") do |event_type|
  steps %(
    Given I ignore invalid sessions
    Given I run \"#{event_type}\"
    And I relaunch the app after a crash
  )
end

When('I clear all persistent data') do
  $reset_data = true
end

When('I configure Bugsnag for {string}') do |scenario_name|
  execute_command :start_bugsnag, scenario_name
end

When('I kill and relaunch the app') do
  case Maze::Helper.get_current_platform
  when 'ios'
    Maze.driver.close_app
    Maze.driver.launch_app
  when 'macos'
    # noop
  when 'watchos'
    # noop
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
  end
end

When("I relaunch the app after a crash") do
  case Maze::Helper.get_current_platform
  when 'ios'
    # Wait for the app to stop running before relaunching
    step 'the app is not running'
    Maze.driver.launch_app
  when 'macos'
    # Wait for the app to stop running before relaunching
    step 'the app is not running'
  when 'watchos'
    sleep 5 # We have no way to poll the app state on watchOS
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
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
  command = { action: action, scenario_name: scenario_name, scenario_mode: $scenario_mode, reset_data: $reset_data }
  Maze::Server.commands.add command
  trigger_app_command
  $scenario_mode = nil
  $reset_data = false
  # Ensure fixture has read the command
  count = 100
  # Launching the fixture via xcdebug is slow
  count = 600 if Maze::Helper.get_current_platform == 'watchos'
  sleep 0.1 until Maze::Server.commands.remaining.empty? || (count -= 1) < 1
  raise 'Test fixture did not GET /command' unless Maze::Server.commands.remaining.empty?
end

def trigger_app_command
  case Maze::Helper.get_current_platform
  when 'ios'
    Maze.driver.click_element :execute_command
  when 'macos'
    run_macos_app
  when 'watchos'
    run_watchos_app
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
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
  if $fixture_pid
    Process.kill 'KILL', $fixture_pid
    Process.waitpid $fixture_pid
  end
  $fixture_pid = Process.spawn(
    { 'MAZE_RUNNER' => 'TRUE' },
    'features/fixtures/macos/output/macOSTestApp.app/Contents/MacOS/macOSTestApp',
    %i[err out] => :close
  )
end

def run_watchos_app
  system(
    "xcdebug --workspace watchOSTestApp.xcworkspace --scheme 'watchOSTestApp WatchKit App' --build --background --destination platform=watchOS", exception: true
  )
end
