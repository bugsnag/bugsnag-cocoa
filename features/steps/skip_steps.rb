BeforeAll do
  $skip_remaining = false
end

Before do
  skip_this_scenario if $skip_remaining
end

Given('The Appium session is ok') do
  # Do nothing
end

Given('The Appium session terminates') do
  $logger.error 'Appium session terminated - ending the run'
  $skip_remaining = true
  # fail 'Appium session terminated'
  exit false
end

Given('This scenario won\'t be run') do
  fail 'This scenario should not have been run'
end
