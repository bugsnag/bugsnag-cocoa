
desc 'Update submodules'
task :submodule do
  sh "git submodule update --init --recursive"
end

desc 'Clean'
task :clean do
  sh "xcodebuild  -scheme Bugsnag -target Bugsnag -configuration Release clean"
end

desc 'Run the tests'
task test: [:submodule] do
  sh "xcodebuild  -scheme Bugsnag -target Bugsnag -configuration Release test"
end

desc 'Build the framework'
task build: [:submodule] do
  sh "xcodebuild -target Bugsnag build"
end

task :default => [:test]
