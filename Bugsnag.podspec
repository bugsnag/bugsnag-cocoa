
Pod::Spec.new do |s|
  s.name         = "Bugsnag"
  s.version      = File.open('VERSION') {|f| f.read.chomp}
  s.summary      = "Cocoa notifier for SDK for bugsnag.com"
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = { "Bugsnag" => "notifiers@bugsnag.com" }

  s.source       = { :git => "https://github.com/bugsnag/bugsnag-cocoa.git", :tag=>"v#{s.version}", :submodules => true }
  s.frameworks   = 'Foundation'
  s.libraries    = 'c++'
  s.xcconfig     = { 'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES' }

  s.platforms    = {:ios =>  "5.0", :osx => "10.7"}

  s.source_files = ["KSCrashModule/Source/KSCrash/Recording/**/*.{m,h,mm,c,cpp}",
                    "KSCrashModule/Source/KSCrash/Reporting/Filters/BugsnagKSCrashReportFilter.h",
                    "Source/Bugsnag/**/*.{m,h,mm,c,cpp}"]

  s.exclude_files = ["KSCrashModule/Source/KSCrash/Recording/Tools/BugsnagKSZombie.{h,m}"]

  s.requires_arc = true

  s.public_header_files = ["Source/Bugsnag/*.h", "KSCrashModule/Source/KSCrash/Reporting/Filters/BugsnagKSCrashReportFilter.h"]

  s.subspec 'no-arc' do |sp|
    sp.source_files = ["KSCrashModule/Source/KSCrash/Recording/Tools/BugsnagKSZombie.{h,m}"]
    sp.requires_arc = false
  end
end
