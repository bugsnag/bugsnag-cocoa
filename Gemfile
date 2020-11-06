source 'https://rubygems.org'

gem 'cocoapods'
gem 'xcpretty'

# A reference to Maze Runner is only needed for running tests locally and if committed it must be
# portable for CI, e.g. a specific release.  However, leaving it commented out means quicker CI.
# gem 'bugsnag-maze-runner', git: 'https://github.com/bugsnag/maze-runner', tag: 'v3.3.0'

# Or follow master:
# gem 'bugsnag-maze-runner', git: 'https://github.com/bugsnag/maze-runner'

install_if -> { File.directory?('../maze-runner') } do
  # Locally, you can run against Maze Runner branches and uncommitted changes:
  gem 'bugsnag-maze-runner', path: '../maze-runner'
end
