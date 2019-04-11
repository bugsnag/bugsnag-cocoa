# Any 'run once' setup should go here as this file is evaluated
# when the environment loads.
# Any helper functions added here will be available in step
# definitions

RUNNING_CI = ENV['TRAVIS'] == 'true'

Dir.chdir('features/fixtures/ios-swift-cocoapods') do
  run_required_commands([
    ['bundle', 'install'],
    ['bundle', 'exec', 'pod', 'install'],
    ['../../scripts/build_ios_app.sh'],
    ['../../scripts/remove_installed_simulators.sh'],
    ['../../scripts/launch_ios_simulators.sh'],
    ['../../scripts/pre_launch.sh'],
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

