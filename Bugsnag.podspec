
Pod::Spec.new do |s|
  s.name         = "Bugsnag"
  s.version      = File.open('VERSION') {|f| f.read.chomp}
  s.summary      = "Cocoa notifier for SDK for bugsnag.com"
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = {"Bugsnag" => "notifiers@bugsnag.com" }
  s.source       = {:git => "https://github.com/bugsnag/bugsnag-cocoa.git",
                    :tag=>"v#{s.version}"}
  s.frameworks   = 'Foundation'
  s.platforms    = {:ios =>  "5.0", :osx => "10.7"}
  s.source_files = ["Source/Bugsnag/**/*.{m,h,mm,c,cpp}"]
  s.requires_arc = true

  s.public_header_files = ["Source/Bugsnag/*.h"]
  s.dependency "KSCrash/Recording", "~> 0.0.8"
  s.dependency "KSCrash/Reporting", "~> 0.0.8"
end
