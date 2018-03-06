When("I select {string} on the website") do |menu_item|
steps %Q{
  When I set environment variable "menu_item" to "#{menu_item}"
  And I run the script "features/scripts/send_request.sh"
  And I wait for 1 second
}
end
