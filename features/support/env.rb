require 'fileutils'

BeforeAll do
  $api_key = "12312312312312312312312312312312"

  $app_env = {
    'LLVM_PROFILE_FILE' => '%c%p.profraw',
    'MAZE_RUNNER' => 'TRUE'
  }

  Maze.config.receive_no_requests_wait = 15
  Maze.config.document_server_root = 'features/fixtures/docs'

  # Setup a 3 minute timeout for receiving requests is STRESS_TEST env var is set
  Maze.config.receive_requests_wait = 180 unless ENV['STRESS_TEST'].nil?

  if Maze.config.os == 'ios' && Maze.config.farm == :local
    # Recent Appium versions don't always uninstall the old version of the app ¯\_(ツ)_/¯
    system('ideviceinstaller --uninstall com.bugsnag.fixtures.cocoa')
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

Before('@skip') do |_scenario|
  skip_this_scenario("Skipping scenario")
end

Before('@skip_ios_16') do |_scenario|
  skip_between('ios', 16, 16.99)
end

Before('@skip_ios_17') do |_scenario|
  skip_between('ios', 17, 17.99)
end

Before('@skip_below_ios_11') do |_scenario|
  skip_below('ios', 11)
end

Before('@skip_below_ios_13') do |_scenario|
  skip_below('ios', 13)
end

Before('@skip_below_ios_17') do |_scenario|
  skip_below('ios', 17)
end

Before('@skip_below_macos_10_15') do |_scenario|
  skip_below('macos', 10.15)
end

Before('@skip_macos') do |_scenario|
  skip_this_scenario("Skipping scenario") if Maze::Helper.get_current_platform == 'macos'
end

# Skip stress tests unless STRESS_TEST env var is set
Before('@stress_test') do |_scenario|
  skip_this_scenario('Skipping: Run is not configured for stress tests') if ENV['STRESS_TEST'].nil?
end

# Handles app-hang test failures, enabling restarts if required
After('@app_hang_test') do |scenario|
  if scenario.failed?

    # If an assertion has failed, conditionally skip the retry
    unless scenario.result.exception.is_a?(Test::Unit::AssertionFailedError)
      Maze::Hooks::ErrorCodeHook.exit_code = Maze::Api::ExitCode::APPIUM_APP_HANG_FAILURE
    end
  end
end

Maze.hooks.before do |_scenario|
  next unless ENV['STRESS_TEST'].nil?

  # Reset to defaults in case previous scenario changed them
  Maze.config.captured_invalid_requests = Set[:errors, :sessions, :builds, :uploads, :sourcemaps]

  $launch_count = 1
  launch_app

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
      if ENV['DEBUG']
        sleep 1 # prevent log bleed between scenarios due to second precision of --start
        app = ENV['RUN_XCFRAMEWORK_APP'] ? 'macOSTestAppXcFramework' : 'macOSTestApp'
        log = Process.spawn(
          '/usr/bin/log', 'show', '--style', 'syslog', '--predicate',
          "eventMessage contains \"#{app}\" OR process == \"#{app}\"",
          '--start', $started_at.strftime('%Y-%m-%d %H:%M:%S%z'),
          out: File.open(File.join(path, 'device.log'), 'w')
        )
        Process.wait log
      end
    end
  when 'ios'
    manager = Maze::Api::Appium::FileManager.new
    begin
      data = manager.read_app_file 'kscrash.log'
      File.open(File.join(path, 'kscrash.log'), 'wb') { |file| file << data }
    rescue StandardError
      puts "read_app_file failed: #{$ERROR_INFO}"
    end
  end
end
