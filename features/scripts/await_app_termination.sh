#!/usr/bin/env ruby

start = Time.now

def is_running()
  output = `xcrun simctl spawn maze-sim launchctl print system | grep UIKitApplication:com.bugsnag.iOSTestApp`
  output.strip != ""
end

while is_running()
  raise "Never crashed! Waited 60s." if Time.now - start > 60
  puts "Awaiting app crash..."
  sleep 1
end
