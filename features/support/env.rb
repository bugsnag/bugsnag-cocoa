require 'fileutils'

BeforeAll do
  $api_key = "12312312312312312312312312312312"

  $app_env = {
    'LLVM_PROFILE_FILE' => '%c%p.profraw',
    'MAZE_RUNNER' => 'TRUE'
  }

  Maze.config.receive_no_requests_wait = 15

  # Setup a 3 minute timeout for receiving requests is STRESS_TEST env var is set
  Maze.config.receive_requests_wait = 180 unless ENV['STRESS_TEST'].nil?

  if Maze.config.os == 'ios' && Maze.config.farm == :local
    # Recent Appium versions don't always uninstall the old version of the app ¯\_(ツ)_/¯
    system('ideviceinstaller --uninstall com.bugsnag.iOSTestApp')
  end

  if Maze.config.os == 'ios'
    capabilities = JSON.parse(Maze.config.capabilities_option)
    capabilities['processArguments'] = { 'env' => $app_env }
    Maze.config.capabilities_option = JSON.dump(capabilities)
  end

  if Maze.config.os == 'macos'
    Maze.config.os_version ||= `sw_vers -productVersion`.to_f

    # MallocScribble results in intermittent crashes in CFNetwork on macOS 10.13
    enable_malloc_scribble if Maze.config.os_version > 10.13

    disable_unexpectedly_quit_dialog
  end
end

# Disables the "macOSTestApp quit unexpectedly" dialog to prevent focus being stolen from the fixture.
def disable_unexpectedly_quit_dialog
  if Maze.config.os_version.floor == 11
    # com.apple.CrashReporter defaults seem to be ignored on macOS 11
    # Note: unloading com.apple.ReportCrash disables creation of crash reports in ~/Library/Logs/DiagnosticReports
    `/bin/launchctl unload /System/Library/LaunchAgents/com.apple.ReportCrash.plist`
    at_exit do
      `/bin/launchctl load /System/Library/LaunchAgents/com.apple.ReportCrash.plist`
    end
  else
    # Use Notification Center instead of showing dialog.
    `defaults write com.apple.CrashReporter UseUNC 1`
  end
end

def enable_malloc_scribble
  $logger.info 'Enabling MallocScribble'
  env = {
    'MallocCheckHeapAbort' => 'TRUE',
    'MallocCheckHeapStart' => '1000',
    'MallocErrorAbort' => 'TRUE',
    'MallocGuardEdges' => 'TRUE',
    'MallocScribble' => 'TRUE'
  }
  $app_env.merge! env
end

def skip_below(os, version)
  skip_this_scenario("Skipping scenario") if Maze::Helper.get_current_platform == os and Maze.config.os_version < version
end

def skip_between(os, version_lo, version_hi)
  skip_this_scenario("Skipping scenario") if Maze::Helper.get_current_platform == os and Maze.config.os_version >= version_lo and Maze.config.os_version <= version_hi
end

Before('@skip_ios_16') do |scenario|
  skip_between('ios', 16, 16.99)
end

Before('@skip_below_ios_11') do |scenario|
  skip_below('ios', 11)
end

Before('@skip_below_ios_13') do |scenario|
  skip_below('ios', 13)
end

Before('@skip_below_macos_10_15') do |scenario|
  skip_below('macos', 10.15)
end

Before('@skip_macos') do |scenario|
  skip_this_scenario("Skipping scenario") if Maze::Helper.get_current_platform == 'macos'
end

# Skip stress tests unless STRESS_TEST env var is set
Before('@stress_test') do |_scenario|
  skip_this_scenario('Skipping: Run is not configured for stress tests') if ENV['STRESS_TEST'].nil?
end

Maze.hooks.before do |_scenario|
  # Reset to defaults in case previous scenario changed them
  Maze.config.captured_invalid_requests = Set[:errors, :sessions, :builds, :uploads, :sourcemaps]

  $started_at = Time.now
end

Maze.hooks.after do |scenario|
  next unless ENV['STRESS_TEST'].nil?

  folder1 = File.join(Dir.pwd, 'maze_output')
  folder2 = scenario.failed? ? 'failed' : 'passed'
  folder3 = scenario.name.gsub(/[:"& ]/, "_").gsub(/_+/, "_")

  path = File.join(folder1, folder2, folder3)

  FileUtils.makedirs(path)

  case Maze::Helper.get_current_platform
  when 'macos'
    if $fixture_pid # will be nil if scenario was skipped
      Process.kill 'KILL', $fixture_pid
      Process.waitpid $fixture_pid
      $fixture_pid = nil
      sleep 1 # prevent log bleed between scenarios due to second precision of --start
      log = Process.spawn(
        '/usr/bin/log', 'show', '--style', 'syslog', '--predicate',
        'eventMessage contains "macOSTestApp" OR process == "macOSTestApp"',
        '--start', $started_at.strftime('%Y-%m-%d %H:%M:%S%z'),
        out: File.open(File.join(path, 'device.log'), 'w')
      )
      Process.wait log
      FileUtils.mv '/tmp/kscrash.log', path
    end
  when 'ios'
    begin
      data = Maze.driver.pull_file '@com.bugsnag.iOSTestApp/Documents/kscrash.log'
      File.open(File.join(path, 'kscrash.log'), 'wb') { |file| file << data }
    rescue StandardError
      puts "Maze.driver.pull_file failed: #{$ERROR_INFO}"
    end
  end
end
