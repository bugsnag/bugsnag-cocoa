When("I run {string} with the defaults on {string}") do |eventType, simulator|
  wait_time = RUNNING_CI ? '20' : '1'
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{eventType}"
    And I set environment variable "iOS_Simulator" to "#{simulator}"
    And I launch the app
    And I wait for #{wait_time} seconds
  }
end

When("I launch the app") do
  wait_time = RUNNING_CI ? '10' : '5'
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for #{wait_time} seconds
  }
end
When("I relaunch the app") do
  wait_time = RUNNING_CI ? '20' : '9'
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for #{wait_time} seconds
  }
end
When("I configure the app to run on {string}") do |device|
  steps %Q{
    And I set environment variable "iOS_Simulator" to "#{device}"
  }
end
When("I crash the app using {string}") do |event|
  steps %Q{
    When I set environment variable "EVENT_TYPE" to "#{event}"
    And I launch the app
    And I set environment variable "EVENT_TYPE" to "none"
  }
end
