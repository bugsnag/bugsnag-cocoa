# Any 'run once' setup should go here as this file is evaluated
# when the environment loads.
# Any helper functions added here will be available in step
# definitions

RUNNING_CI = ENV['TRAVIS'] == 'true'

# Max time in seconds to wait for an action to complete
MAX_WAIT_TIME = RUNNING_CI ? 300 : 60

ENV['MAZE_SDK'] = '12.1' unless ENV['MAZE_SDK']
MAZE_SDK = ENV['MAZE_SDK']

Dir.chdir('features/fixtures/ios-swift-cocoapods') do
  run_required_commands([
    ['bundle', 'install'],
    ['bundle', 'exec', 'pod', 'install'],
    ['../../scripts/build_ios_app.sh'],
    ['../../scripts/remove_installed_simulators.sh'],
    ['../../scripts/launch_ios_simulators.sh'],
  ])
end


# Scenario hooks
Before do
  # Name set in launch_ios_simulators.sh
  set_script_env('iOS_Simulator', 'maze-sim')
end

After do
  # Clean up caches
  files = Dir.glob("#{app_file_path}/**/Library/Caches/{KSCrashReports/,bugsnag_}*")
  files.each {|f| FileUtils.rm_rf(f) }
end

at_exit do
  run_required_commands([
    ['features/scripts/remove_installed_simulators.sh'],
  ])
end

def app_file_path
  app_path = `xcrun simctl get_app_container maze-sim com.bugsnag.iOSTestApp`.chomp
  app_path.gsub(/(.*Containers).*/, '\1')
end

def test_app_pid
  output = `xcrun simctl spawn maze-sim launchctl print system | grep UIKitApplication:com.bugsnag.iOSTestApp`
  pattern = /(\d+)\s+(-|-?\d+?)\s+UIKitApplication:com.bugsnag.iOSTestApp/
  match = output.match(pattern)
  if match.nil?
    nil
  else
    match[1]
  end
end

def test_app_is_running?
  pid = test_app_pid
  !pid.nil? # check that PID is valid
end

def kill_test_app(attempt_retry = true)
  pid = test_app_pid
  start = Time.now
  while pid == '0'
    sleep 0.2
    pid = test_app_pid
    raise "Never received app PID! Waited #{MAX_WAIT_TIME}s." if Time.now - start > MAX_WAIT_TIME
  end
  sleep 1
  `kill -9 #{pid} &` if pid
  kill_time = Time.now
  while test_app_is_running?
    if Time.now - kill_time > 10
      if attempt_retry
        kill_test_app(false)
      else
        raise "Test app was not successfully killed"
      end
    end
  end
end
