require 'fileutils'

BeforeAll do
  $api_key = "12312312312312312312312312312312"

  Maze.config.receive_no_requests_wait = 15

  # Setup a 3 minute timeout for receiving requests is STRESS_TEST env var is set
  Maze.config.receive_requests_wait = 180 unless ENV['STRESS_TEST'].nil?

  # Additional require MacOS configuration
  if Maze.config.os == 'macos'
    # The default macOS Crash Reporter "#{app_name} quit unexpectedly" alert grabs focus which can cause tests to flake.
    # This option, which appears to have been introduced in macOS 10.11, displays a notification instead of the alert.
    `defaults write com.apple.CrashReporter UseUNC 1`

    fixture_dir = 'features/fixtures/macos/output'
    zip_name = "#{Maze.config.app}.zip"
    app_name = "#{Maze.config.app}.app"
    app_path = "#{fixture_dir}/#{app_name}"
    zip_path = "#{fixture_dir}/#{zip_name}"

    unless File.exist?(app_path) || !File.exist?(zip_path)
      system("cd #{fixture_dir} && unzip -q #{zip_name}", exception: true)
    end
  end
end

def skip_below(os, version)
  skip_this_scenario("Skipping scenario") if Maze::Helper.get_current_platform == os and Maze.config.os_version < version
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
  $started_at = Time.now
end

Maze.hooks.after do |scenario|
  folder1 = File.join(Dir.pwd, 'maze_output')
  folder2 = scenario.failed? ? 'failed' : 'passed'
  folder3 = scenario.name.gsub(/[:"& ]/, "_").gsub(/_+/, "_")

  path = File.join(folder1, folder2, folder3)

  FileUtils.makedirs(path)

  if Maze.config.os == 'macos'
    FileUtils.mv('/tmp/kscrash.log', path)
    Process.kill('KILL', $fixture_pid) if $fixture_pid
    $fixture_pid = nil
    Process.wait(
      Process.spawn(
        '/usr/bin/log', 'show', '--predicate', 'process == "macOSTestApp"',
        '--style', 'syslog', '--start', $started_at.strftime('%Y-%m-%d %H:%M:%S%z'),
        out: File.open(File.join(path, 'device.log'), 'w')
      )
    )
  else
    data = Maze.driver.pull_file '@com.bugsnag.iOSTestApp/Documents/kscrash.log'
    File.open(File.join(path, 'kscrash.log'), 'wb') { |file| file << data }
  end
rescue
  # pull_file can fail on BrowserStack iOS 10 with "Error: Command 'umount' not found"
end
