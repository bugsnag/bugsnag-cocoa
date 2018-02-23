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
