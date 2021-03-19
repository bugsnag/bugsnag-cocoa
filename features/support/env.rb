require 'fileutils'

# Set this explicitly
$api_key = "12312312312312312312312312312312"

AfterConfiguration do |_config|
  Maze.config.receive_no_requests_wait = 15

  # Setup a 3 minute timeout for receiving requests is STRESS_TEST env var is set
  Maze.config.receive_requests_wait = 180 unless ENV['STRESS_TEST'].nil?
end

# Skip stress tests unless STRESS_TEST env var is set
Before('@stress_test') do |_scenario|
  skip_this_scenario('Skipping: Run is not configured for stress tests') if ENV['STRESS_TEST'].nil?
end

# Additional require MacOS configuration
if Maze.config.os == 'macos'
  # The default macOS Crash Reporter "#{app_name} quit unexpectedly" alert grabs focus which can cause tests to flake.
  # This option, which appears to have been introduced in macOS 10.11, displays a notification instead of the alert.
  `defaults write com.apple.CrashReporter UseUNC 1`

  fixture_dir = 'features/fixtures/macos/output'
  app_dir = '/Applications'
  zip_name = "#{Maze.config.app}.zip"
  app_name = "#{Maze.config.app}.app"

  # If built app file already exists, skip unzip
  unless File.exist?("#{fixture_dir}/#{app_name}")
    raise Exception, 'Test fixture build archive not found' unless File.file?("#{fixture_dir}/#{zip_name}")
    `cd #{fixture_dir} && unzip #{zip_name}`
  end

  FileUtils.mv("#{fixture_dir}/#{app_name}", "#{app_dir}/#{app_name}")

  at_exit do
    FileUtils.rm_rf("#{app_dir}/#{app_name}")
  end
end
