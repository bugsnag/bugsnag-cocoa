When('I run {string}') do |scenario_name|
  execute_command "run_scenario", [scenario_name, $scenario_mode || '']
  $scenario_mode = nil
end

When("I run {string} and relaunch the crashed app") do |event_type|
  steps %(
    Given I ignore invalid sessions
    Given I run \"#{event_type}\"
    And I relaunch the app after a crash
  )
end

When('I clear all persistent data') do
  execute_command "reset_data", []
end

When('I configure Bugsnag for {string}') do |scenario_name|
  execute_command "start_bugsnag", [scenario_name, $scenario_mode || '']
  $scenario_mode = nil
end

When('I kill and relaunch the app') do
  kill_and_relaunch_app
end

When("I relaunch the app after a crash") do
  relaunch_crashed_app
end

When('I switch to the web browser for {int} second(s)') do |duration|
  execute_command "background", [duration.to_s]
end

When('I make the test fixture wait for {int} second(s)') do |duration|
  execute_command "wait", [duration.to_s]
end

When('I switch to the web browser') do
  execute_command "background", ["-1"]
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

Then('the app is not running') do
  manager = Maze::Api::Appium::AppManager.new
  wait_for_true('the app is not running') do
    case Maze::Helper.get_current_platform
    when 'ios'
      manager.state == :not_running
    else
      raise "Don't know how to query app state on this platform"
    end
  end
end

When('I invoke {string}') do |method_name|
  execute_command "invoke_method", [method_name]
  # Ensure fixture has read the command
  count = 100
  sleep 0.1 until Maze::Server.commands.remaining.empty? || (count -= 1) < 1
end

When('I invoke {string} with parameter {string}') do |method_name, arg1|
  # Note: The method will usually be of the form "xyzWithParam:"
  execute_command "invoke_method", [method_name, arg1]
  # Ensure fixture has read the command
  count = 100
  sleep 0.1 until Maze::Server.commands.remaining.empty? || (count -= 1) < 1
end

# No platform relevance

When('I clear the error queue') do
  Maze::Server.errors.clear
end


def execute_command(action, args)
  Maze::Server.commands.add({ action: action, args: args, launch_count: $launch_count })
end

def launch_app
  case Maze::Helper.get_current_platform
  when 'ios'
    # Do nothing
  when 'macos'
    run_macos_app
  when 'watchos'
    run_watchos_app
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
  end
end

def relaunch_crashed_app
  # Give it time to settle down
  sleep 1

  case Maze::Helper.get_current_platform
  when 'ios'
    # Wait for the app to stop running before relaunching
    step 'the app is not running'

    Maze::Api::Appium::AppManager.new.activate
  when 'macos'
    sleep 4
    launch_app
  when 'watchos'
    sleep 5 # We have no way to poll the app state on watchOS
    launch_app
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
  end
  $launch_count += 1
end

def kill_and_relaunch_app
  case Maze::Helper.get_current_platform
  when 'ios'
    manager = Maze::Api::Appium::AppManager.new
    manager.terminate
    manager.activate
  when 'macos'
    run_macos_app # This will kill the app if it's running
  when 'watchos'
    # noop
  else
    raise "Unsupported platform: #{Maze::Helper.get_current_platform}"
  end
  $launch_count += 1
end

def wait_for_true(description)
  max_attempts = 300
  attempts = 0
  assertion_passed = false
  until (attempts >= max_attempts) || assertion_passed
    attempts += 1
    assertion_passed = yield
    sleep 0.1
  end
  $logger.warn "Assertion not passed in 30s: #{description}" unless assertion_passed
end

def run_macos_app
  if $fixture_pid
    Process.kill 'KILL', $fixture_pid
    Process.waitpid $fixture_pid
  end
  dir = 'features/fixtures/macos/output'
  if ENV['RUN_XCFRAMEWORK_APP']
    exe = "#{dir}/macOSTestAppXcFramework.app/Contents/MacOS/macOSTestAppXcFramework"
  else
    exe = "#{dir}/macOSTestApp.app/Contents/MacOS/macOSTestApp"
  end

  system("unzip -qd #{dir} #{dir}/macOSTestApp*.zip", exception: true) unless File.exist? exe
  $fixture_pid = Process.spawn($app_env, exe, %i[err out] => '/dev/null')
end

def run_watchos_app
  system(
    "xcdebug --workspace watchOSTestApp.xcworkspace --scheme 'watchOSTestApp WatchKit App' --build --background --destination platform=watchOS", exception: true
  )
end
