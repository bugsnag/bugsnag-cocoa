When('I relaunch the app') do
  case Maze::Helper.get_current_platform
  when 'macos'
    app = Maze.driver.capabilities['app']
    system("killall -KILL #{app} > /dev/null && sleep 1")
    Maze.driver.get(app)
  else
    Maze.driver.launch_app
  end
end

When("I relaunch the app after a crash") do
  # Wait for the app to stop running before relaunching
  step 'the app is not running'
  case Maze::Helper.get_current_platform
  when 'macos'
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
