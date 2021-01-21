require 'fileutils'

# Set this explicitly
$api_key = "12312312312312312312312312312312"

AfterConfiguration do |_config|
  Maze.config.receive_no_requests_wait = 15
end

# Additional require MacOS configuration
if MazeRunner.config.os == 'macos'
  fixture_dir = 'features/fixtures/macos/output'
  app_dir = '/Applications'
  zip_name = "#{MazeRunner.config.app}.zip"
  app_name = "#{MazeRunner.config.app}.app"

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
