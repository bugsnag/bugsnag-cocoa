# Configure app environment
bs_username = ENV['BROWSER_STACK_USERNAME']
bs_access_key = ENV['BROWSER_STACK_ACCESS_KEY']
bs_local_id = ENV['BROWSER_STACK_LOCAL_IDENTIFIER'] || 'maze_browser_stack_test_id'
bs_device = ENV['DEVICE_TYPE']
app_location = ENV['APP_LOCATION']

# Set this explicitly
$api_key = "12312312312312312312312312312312"


After do |scenario|
  if MazeRunner.driver
    # [:syslog, :crashlog, :performance, :server, :safariConsole, :safariNetwork]
    # puts MazeRunner.driver.driver.logs.get(:crashlog)
    MazeRunner.driver.reset_with_timeout
  end
end

AfterConfiguration do |config|
  ResilientAppiumDriver.new(
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
  MazeRunner.driver.start_driver
end

at_exit do
  if MazeRunner.driver
    MazeRunner.driver.close_app
    MazeRunner.driver.driver_quit
  end
end
