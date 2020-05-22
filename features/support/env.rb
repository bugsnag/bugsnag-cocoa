# Configure app environment
bs_username = ENV['BROWSER_STACK_USERNAME']
bs_access_key = ENV['BROWSER_STACK_ACCESS_KEY']
bs_local_id = ENV['BROWSER_STACK_LOCAL_IDENTIFIER'] || 'maze_browser_stack_test_id'
bs_device = ENV['DEVICE_TYPE']
app_location = ENV['APP_LOCATION']

# Set this explicitly
$api_key = "12312312312312312312312312312312"


After do |scenario|
  if $driver
    # [:syslog, :crashlog, :performance, :server, :safariConsole, :safariNetwork]
    # puts $driver.driver.logs.get(:crashlog)
    $driver.reset
  end
end

AfterConfiguration do |config|
  AppAutomateDriver.new(
    bs_username,
    bs_access_key,
    bs_local_id,
    bs_device,
    app_location,
    :accessibility_id,
    {
      'browserstack.deviceLogs' => true,
      'browserstack.appium_version' => '1.15.0' # Temporary fix to allow running on iOS 10
    }
  )
  $driver.start_driver
end

at_exit do
  if $driver
    $driver.close_app
    $driver.driver_quit
  end
end
