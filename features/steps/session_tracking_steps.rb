Then("the payload includes app and device data") do
  steps %Q{
    And the payload field "app.version" is not null
    And the payload field "app.bundleVersion" is not null
    And the payload field "app.releaseStage" is not null
    And the payload field "app.type" is not null
    And the payload field "device.manufacturer" equals "Apple"
    And the payload field "device.jailbroken" is not null
    And the payload field "device.modelNumber" is not null
    And the payload field "device.wordSize" is not null
    And the payload field "device.osVersion" is not null
    And the payload field "device.osName" is not null
    And the payload field "device.model" is not null
  }
end
