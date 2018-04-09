# Any 'run once' setup should go here as this file is evaluated
# when the environment loads.
# Any helper functions added here will be available in step
# definitions

RUNNING_CI = ENV['TRAVIS'] == 'true'
SIMULATOR = `xcrun simctl create iPhone8-11.2 "iPhone 8" "11.2"`

Dir.chdir('features/fixtures/ios-swift-cocoapods') do
  run_required_commands([
    ['bundle', 'install'],
    ['bundle', 'exec', 'pod', 'install'],
    ['../../scripts/build_ios_app.sh'],
    ['../../scripts/launch_ios_simulators.sh'],
  ])
end

# Scenario hooks
Before do
# Runs before every Scenario
end

at_exit do
  run_required_commands([
    ['xcrun', 'simctl', 'delete', SIMULATOR]
  ])
end
