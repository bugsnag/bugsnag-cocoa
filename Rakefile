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

desc 'Vendor KSCrash'
task :vendor do
  sh "git submodule update --init --recursive"
  sh "cp -r KSCrashModule/* KSCrash/"
  sh "git add KSCrash && git commit -am 'vendor KSCrash'"
end

task :default => [:test]
