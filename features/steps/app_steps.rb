When('I background the app for {int} seconds') do |duration|
  Maze.driver.background_app(duration)
end

When('I relaunch the app') do
  case Maze.driver.capabilities['platformName']
  when 'Mac'
    app = Maze.driver.capabilities['app']
    system("killall #{app} > /dev/null && sleep 1")
    Maze.driver.get(app)
  else
    Maze.driver.launch_app
  end
end

When("I relaunch the app after a crash") do
  # This step should only be used when the app has crashed, but the notifier needs a little
  # time to write the crash report before being forced to reopen.  From trials, 2s was not enough.
  sleep(5)
  case Maze.driver.capabilities['platformName']
  when 'Mac'
    Maze.driver.get(Maze.driver.capabilities['app'])
  else
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
    case Maze.driver.capabilities['platformName']
    when 'iOS'
      Maze.driver.app_state('com.bugsnag.iOSTestApp') == :not_running
    when 'Mac'
      `lsappinfo info -only pid -app com.bugsnag.macOSTestApp`.empty?
    else
      raise "Don't know how to query app state on this platform"
    end
  end
end

When('I set the app to {string} mode') do |mode|
  steps %(
    Given the element "scenario_metadata" is present
    When I send the keys "#{mode}" to the element "scenario_metadata"
    And I close the keyboard
  )
end

When('I send the app to the background') do
  Maze.driver.background_app(-1)
end
