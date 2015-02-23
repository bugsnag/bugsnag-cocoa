require 'cocoapods'

desc 'Clean'
task :clean do
  sh "xcodebuild  -scheme Bugsnag -target Bugsnag -configuration Release clean"
end

desc 'Run the tests'
task test: [:submodule] do
  sh "xcodebuild  -scheme Bugsnag -target Bugsnag -configuration Release test"
end

desc 'Build the framework'
task :build do

  podspec = eval File.read("Bugsnag.podspec"), TOPLEVEL_BINDING, "Bugsnag.podspec", 1
  version = podspec.version.to_s

  sh "xcodebuild -target Bugsnag build"

  Dir.chdir "build/Release" do
    sh "zip -r Bugsnag-#{version}.zip Bugsnag.framework"
    sh "open ."
    sh "open https://github.com/bugsnag/bugsnag-cocoa/releases/new?tag=v#{version}"
  end
end

desc 'Vendor KSCrash'
task :vendor do
  sh "git submodule update --init --recursive"
  sh "cp -r KSCrashModule/* KSCrash/"
  sh "git add KSCrash && git commit -am 'vendor KSCrash'"
end

task :default => [:test]
