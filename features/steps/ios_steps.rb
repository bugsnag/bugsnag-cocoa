When("I run {string} with the defaults") do |eventType|
  steps %Q{
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "#{eventType}"
    And I set environment variable "SIMULATOR" to "iPhone 8"
    And I install the app
    And I launch the app
  }
end

When("I build the app") do
  steps %Q{
    When I run the script "features/scripts/build_ios_app.sh" synchronously
    And I wait for 1 second
  }
end
When("I install the app") do
  steps %Q{
    When I run the script "features/scripts/install_ios_app.sh" synchronously
    And I wait for 1 second
  }
end
When("I launch the app") do
  steps %Q{
    When I run the script "features/scripts/launch_ios_app.sh"
    And I wait for 5 seconds
  }
end
